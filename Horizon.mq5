#property copyright "Horizon5, by Pedro Carvajal"
#property version "0.416"
#property description "Advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization."

#include <Trade/Trade.mqh>

#include "configs/Assets.mqh"

#include "constants/COHorizon.mqh"
#include "constants/COTime.mqh"

#include "entities/EAccount.mqh"

#include "enums/EDebugLevel.mqh"
#include "enums/ESnapshotEvent.mqh"

#include "structs/STradingStatus.mqh"

#include "helpers/HGetPipSize.mqh"
#include "helpers/HGetPipValue.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "helpers/HGetSystemName.mqh"
#include "helpers/HInitializeMessageBus.mqh"

#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"
#include "services/SRImplementationOfHorizonMonitor/SRImplementationOfHorizonMonitor.mqh"
#include "services/SRImplementationOfHorizonGateway/SRImplementationOfHorizonGateway.mqh"
#include "services/SRReportOfMonitorSeed/SRReportOfMonitorSeed.mqh"
#include "services/SRAccountAuditor/SRAccountAuditor.mqh"

EAccount account;
SEDateTime dtime;
SELogger logger;
SRImplementationOfHorizonMonitor horizonMonitor;
SRImplementationOfHorizonGateway horizonGateway;
STradingStatus tradingStatus;
SRReportOfMonitorSeed *monitorSeedReporter = NULL;
SRAccountAuditor accountAuditor;

input group "General Settings";
input int TickIntervalTime = 60; // [1] > Tick interval (1 = 1 second by tick)
input ENUM_ORDER_TYPE_FILLING FillingMode = ORDER_FILLING_IOC; // [1] > Order filling mode
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "Reporting > Strategy Reports";
input bool EnableOrderHistoryReport = false; // [1] > Export per-strategy order history
input bool EnableSnapshotHistoryReport = false; // [1] > Export per-strategy snapshots
input bool EnableMarketHistoryReport = false; // [1] > Export per-asset market snapshots

input group "Reporting > Monitor Seed";
input bool EnableSeedAccounts = false; // [1] > Export accounts collection
input bool EnableSeedAssets = false; // [1] > Export assets collection
input bool EnableSeedStrategies = false; // [1] > Export strategies collection
input bool EnableSeedMetadata = false; // [1] > Export metadata collection
input bool EnableSeedOrders = false; // [1] > Export orders collection
input bool EnableSeedSnapshots = false; // [1] > Export account/asset/strategy snapshots

input group "Reporting > Logs";
input bool EnableLogExport = false; // [1] > Export portfolio logs on shutdown

input group "Risk management";
input bool EquityAtRiskCompounded = false; // [1] > Equity at risk compounded
input double EquityAtRisk = 1; // [1] > Equity at risk value (in percentage)

input group "Horizon Monitor";
input bool EnableHorizonMonitor = false; // [1] > Enable Horizon Monitor integration
input string HorizonMonitorUrl = ""; // [1] > HorizonMonitor base URL
input string HorizonMonitorEmail = ""; // [1] > HorizonMonitor email (required)
input string HorizonMonitorPassword = ""; // [1] > HorizonMonitor password (required)

input group "Horizon Gateway";
input bool EnableHorizonGateway = false; // [1] > Enable Horizon Gateway integration
input string HorizonGatewayUrl = ""; // [1] > HorizonGateway base URL
input string HorizonGatewayEmail = ""; // [1] > HorizonGateway email (required)
input string HorizonGatewayPassword = ""; // [1] > HorizonGateway password (required)

int lastCheckedDay = -1;
int lastCheckedHour = -1;
int lastCheckedMinute = -1;
datetime lastTickTime = 0;

bool ValidateMagicNumbers() {
	ulong magicNumbers[];
	string magicSources[];
	int assetCount = ArraySize(assets);

	for (int i = 0; i < assetCount; i++) {
		for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
			ulong currentMagic = assets[i].GetStrategyAtIndex(j).GetMagicNumber();
			string currentSource = StringFormat("%s/%s",
				assets[i].GetSymbol(),
				assets[i].GetStrategyAtIndex(j).GetPrefix());

			for (int k = 0; k < ArraySize(magicNumbers); k++) {
				if (magicNumbers[k] == currentMagic) {
					logger.Error(
						LOG_CODE_CONFIG_INVALID_PARAMETER,
						StringFormat(
							"duplicate magic detected | magic=%llu",
							currentMagic
					));

					logger.Error(
						LOG_CODE_CONFIG_INVALID_PARAMETER,
						StringFormat(
							"magic conflict | existing=%s new=%s",
							magicSources[k],
							currentSource
					));

					return false;
				}
			}

			int size = ArraySize(magicNumbers);
			ArrayResize(magicNumbers, size + 1);
			ArrayResize(magicSources, size + 1);
			magicNumbers[size] = currentMagic;
			magicSources[size] = currentSource;
		}
	}

	if (ArraySize(magicNumbers) == 0) {
		logger.Error(
			LOG_CODE_CONFIG_MISSING_DEPENDENCY,
			"configuration invalid | field=strategies reason='no strategies enabled'"
		);

		return false;
	}

	return true;
}

int BuildRequiredServices(string &services[]) {
	int count = 0;

	ArrayResize(services, 1);
	services[count++] = MB_SERVICE_PERSISTENCE;

	if (horizonMonitor.IsEnabled()) {
		ArrayResize(services, count + 1);
		services[count++] = MB_SERVICE_MONITOR;
	}

	if (horizonGateway.IsEnabled()) {
		ArrayResize(services, count + 1);
		services[count++] = MB_SERVICE_GATEWAY;
	}

	return count;
}

void SendServiceHeartbeats() {
	if (horizonGateway.IsEnabled() && SEMessageBus::IsActive() && SEMessageBus::IsServiceRunning(MB_SERVICE_GATEWAY)) {
		horizonMonitor.StoreSystemHeartbeat(GetSystemName(SYSTEM_GATEWAY_SERVICE));
	}

	if (SEMessageBus::IsActive() && SEMessageBus::IsServiceRunning(MB_SERVICE_PERSISTENCE)) {
		horizonMonitor.StoreSystemHeartbeat(GetSystemName(SYSTEM_PERSISTENCE_SERVICE));
	}
}

void CheckServiceHealth() {
	string requiredServices[];
	int serviceCount = BuildRequiredServices(requiredServices);
	bool servicesRunning = SEMessageBus::AreServicesReady(requiredServices, serviceCount);

	if (servicesRunning && tradingStatus.reason == TRADING_PAUSE_REASON_SERVICES_DOWN) {
		SEMessageBus::Activate();
		logger.Info(
			LOG_CODE_TRADING_PAUSED,
			"trading resumed | reason='services recovered'"
		);
		tradingStatus.isPaused = false;
		tradingStatus.reason = TRADING_PAUSE_REASON_NONE;
	}

	if (!servicesRunning && tradingStatus.reason != TRADING_PAUSE_REASON_SERVICES_DOWN) {
		logger.Error(
			LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
			"trading paused | reason='required services down'"
		);
		SEMessageBus::Shutdown();
		tradingStatus.isPaused = true;
		tradingStatus.reason = TRADING_PAUSE_REASON_SERVICES_DOWN;
	}
}

void CollectAccountSeedSnapshot(ENUM_SNAPSHOT_EVENT event) {
	accountAuditor.CollectAccountSeedSnapshot(event);
}

void InitializeMonitorSeedReporter() {
	string firstSymbol = "";
	for (int i = 0; i < ArraySize(assets); i++) {
		if (assets[i].IsEnabled()) {
			firstSymbol = assets[i].GetSymbol();
			break;
		}
	}

	monitorSeedReporter = new SRReportOfMonitorSeed();
	monitorSeedReporter.Initialize(firstSymbol, "MonitorSeed");
	monitorSeedReporter.RegisterAccount();
}

int OnInit() {
	EventSetTimer(1);

	dtime = SEDateTime();
	logger.SetPrefix("Horizon");

	SELogger::SetGlobalDebugLevel(DebugLevel);
	SELogger::SetLogSystem(LOG_SYSTEM_HORIZON5);

	bool monitorEnabled = IsLiveTrading() && EnableHorizonMonitor;
	bool gatewayEnabled = IsLiveTrading() && EnableHorizonGateway;

	if (!horizonMonitor.Initialize(HorizonMonitorUrl, HorizonMonitorEmail, HorizonMonitorPassword, monitorEnabled)) {
		return INIT_FAILED;
	}

	if (!horizonGateway.Initialize(HorizonGatewayUrl, HorizonGatewayEmail, HorizonGatewayPassword, gatewayEnabled)) {
		return INIT_FAILED;
	}

	if (horizonMonitor.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(horizonMonitor));

		if (!horizonMonitor.UpsertAccount()) {
			logger.Error(
				LOG_CODE_REMOTE_AUTH_FAILED,
				"service idle | reason='monitor account registration failed'"
			);
			return INIT_FAILED;
		}
	}

	if (horizonGateway.IsEnabled()) {
		if (!horizonGateway.UpsertAccount()) {
			logger.Error(
				LOG_CODE_REMOTE_AUTH_FAILED,
				"service idle | reason='gateway account registration failed'"
			);
			return INIT_FAILED;
		}

		string accountStatus = horizonGateway.FetchAccountStatus();

		if (accountStatus != "active") {
			logger.Warning(
				LOG_CODE_TRADING_PAUSED,
				"trading paused | reason='account inactive'"
			);
			tradingStatus.isPaused = true;
			tradingStatus.reason = TRADING_PAUSE_REASON_ACCOUNT_INACTIVE;
		}
	}

	lastCheckedDay = dtime.Today().dayOfYear;
	lastCheckedHour = dtime.Today().hour;

	int assetCount = ArraySize(assets);
	int enabledAssetCount = 0;

	if (assetCount == 0) {
		logger.Warning(
			LOG_CODE_CONFIG_MISSING_DEPENDENCY,
			"configuration invalid | field=assets reason='no assets defined'"
		);
		return INIT_FAILED;
	}

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled()) {
			enabledAssetCount++;
		}
	}

	if (enabledAssetCount == 0) {
		logger.Error(
			LOG_CODE_CONFIG_MISSING_DEPENDENCY,
			"configuration invalid | field=assets reason='no assets enabled'"
		);
		return INIT_FAILED;
	}

	double weightPerAsset = 1.0 / enabledAssetCount;

	bool isMonitorSeedEnabled = EnableSeedAccounts || EnableSeedAssets || EnableSeedStrategies
				    || EnableSeedMetadata || EnableSeedOrders || EnableSeedSnapshots;

	if (isMonitorSeedEnabled) {
		InitializeMonitorSeedReporter();
	}

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled()) {
			assets[i].SetWeight(weightPerAsset);
			assets[i].SetBalance(account.GetBalance() * weightPerAsset);
		}

		int result = assets[i].OnInit();

		if (result != INIT_SUCCEEDED) {
			return INIT_FAILED;
		}
	}

	if (!ValidateMagicNumbers()) {
		return INIT_FAILED;
	}

	accountAuditor.Initialize(assets, assetCount);
	accountAuditor.AuditOrders();

	if (IsLiveTrading()) {
		string requiredServices[];
		int serviceCount = BuildRequiredServices(requiredServices);

		if (!InitializeMessageBus(requiredServices, serviceCount)) {
			logger.Error(
				LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
				"service idle | reason='required services not running'"
			);
			return INIT_FAILED;
		}
	}

	if (horizonMonitor.IsEnabled() || horizonGateway.IsEnabled()) {
		logger.Separator("UUID Mapping Report");

		if (horizonMonitor.IsEnabled()) {
			logger.Info(
				LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
				StringFormat(
					"uuid mapped | system=monitor target=account uuid=%s",
					horizonMonitor.GetAccountUuid()
			));

			for (int i = 0; i < ArraySize(assets); i++) {
				if (!assets[i].IsEnabled()) {
					continue;
				}

				string symbolName = assets[i].GetSymbol();
				logger.Info(
					LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
					StringFormat(
						"uuid mapped | system=monitor target=asset symbol=%s uuid=%s",
						symbolName,
						horizonMonitor.GetAssetUuid(symbolName)
				));

				for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
					ulong magic = assets[i].GetStrategyAtIndex(j).GetMagicNumber();
					string stratName = assets[i].GetStrategyAtIndex(j).GetName();
					logger.Info(
						LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
						StringFormat(
							"uuid mapped | system=monitor target=strategy strategy=%s magic=%llu uuid=%s",
							stratName,
							magic,
							horizonMonitor.GetStrategyUuid(magic)
					));
				}
			}
		}

		if (horizonGateway.IsEnabled()) {
			logger.Info(
				LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
				StringFormat(
					"uuid mapped | system=gateway target=account uuid=%s",
					horizonGateway.GetAccountUuid()
			));

			for (int i = 0; i < ArraySize(assets); i++) {
				if (!assets[i].IsEnabled()) {
					continue;
				}

				string symbolName = assets[i].GetSymbol();
				logger.Info(
					LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
					StringFormat(
						"uuid mapped | system=gateway target=asset symbol=%s uuid=%s",
						symbolName,
						horizonGateway.GetAssetUuid(symbolName)
				));

				for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
					ulong magic = assets[i].GetStrategyAtIndex(j).GetMagicNumber();
					string stratName = assets[i].GetStrategyAtIndex(j).GetName();
					logger.Info(
						LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
						StringFormat(
							"uuid mapped | system=gateway target=strategy strategy=%s magic=%llu uuid=%s",
							stratName,
							magic,
							horizonGateway.GetStrategyUuid(magic)
					));
				}
			}
		}

		logger.Separator("End UUID Mapping Report");
	}

	if (horizonMonitor.IsEnabled()) {
		SendServiceHeartbeats();
	}

	logger.Info(
		LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
		"service started | system=Horizon version=0.416 built='2026-04-15 14:14:55'"
	);

	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
	EventKillTimer();
	SELogger::SetRemoteLogger(NULL);
	SEMessageBus::Shutdown();

	bool isNormalShutdown = (reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS);

	if (isNormalShutdown) {
		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].OnEnd();
		}

		if (EnableLogExport && SELogger::GetGlobalEntryCount() > 0) {
			string logEntries[];
			SELogger::GetGlobalEntries(logEntries);

			SRReportOfLogs logExporter;
			logExporter.Initialize(GetLogsPath("Portfolio"));
			logExporter.Export("Logs", logEntries);

			SELogger::ClearGlobalEntries();
		}
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnDeinit();
	}

	if (isNormalShutdown) {
		for (int i = 0; i < ArraySize(assets); i++) {
			if (CheckPointer(assets[i]) != POINTER_INVALID) {
				delete assets[i];
			}
		}
	}
}

void OnTimer() {
	SDateTime now = dtime.Now();

	bool isStartDay = (now.dayOfYear != lastCheckedDay);
	bool isStartHour = (now.hour != lastCheckedHour);
	bool isStartMinute = (now.minute != lastCheckedMinute);
	bool isTickInterval = (now.timestamp - lastTickTime) >= TickIntervalTime;

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnTimer();
		assets[i].ProcessBarEvents();
	}

	if (isStartDay) {
		lastCheckedDay = now.dayOfYear;

		if (tradingStatus.isPaused
		    && tradingStatus.reason != TRADING_PAUSE_REASON_HORIZON_API_REQUEST
		    && tradingStatus.reason != TRADING_PAUSE_REASON_ACCOUNT_INACTIVE
		    && tradingStatus.reason != TRADING_PAUSE_REASON_SERVICES_DOWN) {
			logger.Info(
				LOG_CODE_TRADING_PAUSED,
				"trading resumed | reason='new day started'"
			);
			tradingStatus.isPaused = false;
			tradingStatus.reason = TRADING_PAUSE_REASON_NONE;
		}

		if (horizonMonitor.IsEnabled()) {
			horizonMonitor.SyncAccount(assets, ArraySize(assets), SNAPSHOT_ON_END_DAY);
		}

		if (monitorSeedReporter != NULL) {
			CollectAccountSeedSnapshot(SNAPSHOT_ON_END_DAY);
		}
	}

	if (isStartHour) {
		lastCheckedHour = now.hour;
	}

	if (isStartMinute) {
		lastCheckedMinute = now.minute;

		if (SEMessageBus::IsActive()) {
			CheckServiceHealth();
		}
	}

	if (isTickInterval) {
		lastTickTime = now.timestamp;

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].OnTick();
		}
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].ProcessOrders();
	}

	if (horizonGateway.IsEnabled() && SEMessageBus::IsActive()) {
		horizonGateway.ProcessServiceEvents(assets);
	}

	if (isStartHour && horizonMonitor.IsEnabled()) {
		if (!isStartDay) {
			horizonMonitor.SyncAccount(assets, ArraySize(assets), SNAPSHOT_ON_HOUR);
		}

		SendServiceHeartbeats();
	}

	if (isStartHour) {
		accountAuditor.AuditOrders();
	}
}

void OnTradeTransaction(
	const MqlTradeTransaction &transaction,
	const MqlTradeRequest &request,
	const MqlTradeResult &result
) {
	if (transaction.type == TRADE_TRANSACTION_HISTORY_ADD) {
		if (HistoryOrderSelect(transaction.order)) {
			ulong orderState = HistoryOrderGetInteger(transaction.order, ORDER_STATE);

			if (orderState == ORDER_STATE_CANCELED || orderState == ORDER_STATE_EXPIRED) {
				for (int i = 0; i < ArraySize(assets); i++) {
					if (assets[i].HandleOrderCancellation(transaction.order)) {
						break;
					}
				}
			}
		}
	}

	if (!HistoryDealSelect(transaction.deal)) {
		return;
	}

	ulong magic = HistoryDealGetInteger(transaction.deal, DEAL_MAGIC);
	bool isValidMagic = false;

	for (int i = 0; i < ArraySize(assets); i++) {
		if (assets[i].HasMagicNumber(magic)) {
			isValidMagic = true;
			break;
		}
	}

	if (!isValidMagic && magic != 0) {
		return;
	}

	if (transaction.type != TRADE_TRANSACTION_DEAL_ADD) {
		return;
	}

	int entry = (int)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);

	if (entry == DEAL_ENTRY_OUT) {
		HandleDealCloseTransaction(transaction.position, transaction.deal);
	} else if (entry == DEAL_ENTRY_IN) {
		HandleDealOpenTransaction(transaction.order, transaction.deal);
	}
}

void HandleDealCloseTransaction(ulong positionId, ulong dealId) {
	SDateTime dealTime = dtime.Now();
	double dealPrice = HistoryDealGetDouble(dealId, DEAL_PRICE);
	double dealProfit = HistoryDealGetDouble(dealId, DEAL_PROFIT);
	double dealCommission = HistoryDealGetDouble(dealId, DEAL_COMMISSION);
	double dealSwap = HistoryDealGetDouble(dealId, DEAL_SWAP);
	double netProfit = dealProfit + (dealCommission * COMMISSION_ROUND_TRIP_MULTIPLIER) + dealSwap;
	ENUM_DEAL_REASON dealReason =
		(ENUM_DEAL_REASON)HistoryDealGetInteger(dealId, DEAL_REASON);

	bool isFound = false;
	for (int i = 0; i < ArraySize(assets); i++) {
		if (assets[i].HandleDealClose(
			positionId, dealTime, dealPrice, netProfit,
			dealProfit, dealCommission, dealSwap, dealReason
		    )) {
			isFound = true;
			break;
		}
	}

	if (!isFound) {
		logger.Warning(
			LOG_CODE_ORDER_NOT_FOUND,
			StringFormat(
				"order not found | position_id=%llu reason='trade transaction handler'",
				positionId
		));
	}
}

void HandleDealOpenTransaction(ulong orderId, ulong dealId) {
	double dealPrice = HistoryDealGetDouble(dealId, DEAL_PRICE);
	bool isFound = false;

	for (int i = 0; i < ArraySize(assets); i++) {
		if (assets[i].HandleDealOpen(orderId, dealId, dealPrice)) {
			isFound = true;
			break;
		}
	}

	if (!isFound) {
		logger.Warning(
			LOG_CODE_ORDER_NOT_FOUND,
			StringFormat(
				"order not found | order_ticket=%llu reason='trade transaction handler'",
				orderId
		));
	}
}

double OnTester() {
	double quality = 1.0;

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].ForceEndStatistics();
		double assetQuality = assets[i].CalculateQualityProduct();

		if (assetQuality == 0) {
			quality = 0;
		} else {
			quality = MathSqrt(quality * assetQuality);
		}
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].ExportOrderHistory();
		assets[i].ExportStrategySnapshots();
		assets[i].ExportMarketSnapshots();
	}

	if (monitorSeedReporter != NULL) {
		monitorSeedReporter.Export();
		delete monitorSeedReporter;
		monitorSeedReporter = NULL;
	}

	return quality;
}

int OnTesterInit() {
	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnTesterInit();
	}

	return INIT_SUCCEEDED;
}

void OnTesterPass() {
}

void OnTesterDeinit() {
}
