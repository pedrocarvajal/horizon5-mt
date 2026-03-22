#property copyright "Horizon5, by Pedro Carvajal"
#property version "1.81"
#property description "Advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization."

#include <Trade/Trade.mqh>

#define COMMISSION_ROUND_TRIP_MULTIPLIER 2

#include "configs/Assets.mqh"
#include "constants/time.mqh"

#include "entities/EAccount.mqh"
#include "enums/EDebugLevel.mqh"
#include "enums/ELogSystem.mqh"
#include "structs/STradingStatus.mqh"

#include "helpers/HGetPipSize.mqh"
#include "helpers/HGetPipValue.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "helpers/HInitializeMessageBus.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

#include "services/SRImplementationOfHorizonMonitor/SRImplementationOfHorizonMonitor.mqh"
#include "services/SRImplementationOfHorizonGateway/SRImplementationOfHorizonGateway.mqh"

EAccount account;
SEDateTime dtime;
SELogger logger;
SRImplementationOfHorizonMonitor horizonMonitor;
SRImplementationOfHorizonGateway horizonGateway;
STradingStatus tradingStatus;

input group "General Settings";
input int TickIntervalTime = 60; // [1] > Tick interval (1 = 1 second by tick)
input ENUM_ORDER_TYPE_FILLING FillingMode = ORDER_FILLING_IOC; // [1] > Order filling mode
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level
input group "Reporting";
input bool EnableOrderHistoryReport = false; // [1] > Enable order history report on tester
input bool EnableSnapshotHistoryReport = false; // [1] > Enable snapshot history report on tester
input bool EnableMarketHistoryReport = false; // [1] > Enable market history report on tester

input group "Risk management";
input bool EquityAtRiskCompounded = false; // [1] > Equity at risk compounded
input double EquityAtRisk = 1; // [1] > Equity at risk value (in percentage)

input group "Horizon Monitor";
input bool EnableHorizonIntegration = true; // [1] > Enable Horizon integration
input string HorizonMonitorUrl = ""; // [1] > HorizonMonitor base URL
input string HorizonMonitorEmail = ""; // [1] > HorizonMonitor email (required)
input string HorizonMonitorPassword = ""; // [1] > HorizonMonitor password (required)
input group "Horizon Gateway";
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
					logger.Error(StringFormat(
						"Duplicate magic number detected: %llu",
						currentMagic
					));

					logger.Error(StringFormat(
						"Conflict between: %s and %s",
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
			"No strategies enabled. Enable at least one strategy to start."
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

void CheckServiceHealth() {
	string requiredServices[];
	int serviceCount = BuildRequiredServices(requiredServices);
	bool servicesRunning = SEMessageBus::AreServicesReady(requiredServices, serviceCount);

	if (servicesRunning && tradingStatus.reason == TRADING_PAUSE_REASON_SERVICES_DOWN) {
		SEMessageBus::Activate();
		logger.Info("Services recovered, trading resumed");
		tradingStatus.isPaused = false;
		tradingStatus.reason = TRADING_PAUSE_REASON_NONE;
	}

	if (!servicesRunning && tradingStatus.reason != TRADING_PAUSE_REASON_SERVICES_DOWN) {
		logger.Error("Required services went down, trading paused");
		SEMessageBus::Shutdown();
		tradingStatus.isPaused = true;
		tradingStatus.reason = TRADING_PAUSE_REASON_SERVICES_DOWN;
	}
}

int OnInit() {
	EventSetTimer(1);

	dtime = SEDateTime();
	logger.SetPrefix("Horizon");

	SELogger::SetGlobalDebugLevel(DebugLevel);
	SELogger::SetLogSystem(LOG_SYSTEM_HORIZON5);

	bool integrationEnabled = IsLiveTrading() && EnableHorizonIntegration;

	if (!horizonMonitor.Initialize(HorizonMonitorUrl, HorizonMonitorEmail, HorizonMonitorPassword, integrationEnabled)) {
		return INIT_FAILED;
	}

	if (!horizonGateway.Initialize(HorizonGatewayUrl, HorizonGatewayEmail, HorizonGatewayPassword, integrationEnabled)) {
		return INIT_FAILED;
	}

	if (horizonMonitor.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(horizonMonitor));

		if (!horizonMonitor.UpsertAccount()) {
			logger.Error("Failed to register account on Monitor");
			return INIT_FAILED;
		}
	}

	if (horizonGateway.IsEnabled()) {
		if (!horizonGateway.UpsertAccount()) {
			logger.Error("Failed to register account on Gateway");
			return INIT_FAILED;
		}

		string accountStatus = horizonGateway.FetchAccountStatus();

		if (accountStatus != "active") {
			logger.Warning("Account is inactive, trading paused.");
			tradingStatus.isPaused = true;
			tradingStatus.reason = TRADING_PAUSE_REASON_ACCOUNT_INACTIVE;
		}
	}

	lastCheckedDay = dtime.Today().dayOfYear;
	lastCheckedHour = dtime.Today().hour;

	int assetCount = ArraySize(assets);
	int enabledAssetCount = 0;

	if (assetCount == 0) {
		logger.Warning("No assets are defined.");
		return INIT_FAILED;
	}

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled()) {
			enabledAssetCount++;
		}
	}

	if (enabledAssetCount == 0) {
		logger.Error("No assets are enabled.");
		logger.Error("Enable at least one asset to start.");
		return INIT_FAILED;
	}

	double weightPerAsset = 1.0 / enabledAssetCount;

	for (int i = 0; i < assetCount; i++) {
		if (!assets[i].IsEnabled()) {
			continue;
		}

		assets[i].SetWeight(weightPerAsset);
		assets[i].SetBalance(account.GetBalance() * weightPerAsset);

		int result = assets[i].OnInit();

		if (result != INIT_SUCCEEDED) {
			return INIT_FAILED;
		}
	}

	if (!ValidateMagicNumbers()) {
		return INIT_FAILED;
	}

	if (IsLiveTrading()) {
		int trackedOrderCount = 0;
		int trackedStrategyCount = 0;

		for (int i = 0; i < assetCount; i++) {
			if (!assets[i].IsEnabled()) {
				continue;
			}

			for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
				trackedStrategyCount++;
				SEOrderBook *book = assets[i].GetStrategyAtIndex(j).GetOrderBook();
				trackedOrderCount += book.GetOpenOrderCount();
			}
		}

		int metatraderPositions = PositionsTotal();
		int metatraderPendingOrders = OrdersTotal();

		logger.Info(StringFormat(
			"Order summary | MT5 positions: %d | MT5 pending: %d | Tracked orders: %d | Strategies: %d",
			metatraderPositions,
			metatraderPendingOrders,
			trackedOrderCount,
			trackedStrategyCount
		));
	}

	if (IsLiveTrading()) {
		string requiredServices[];
		int serviceCount = BuildRequiredServices(requiredServices);

		if (!InitializeMessageBus(requiredServices, serviceCount)) {
			logger.Error("Required services not running, cannot start.");
			return INIT_FAILED;
		}
	}

	if (horizonMonitor.IsEnabled() || horizonGateway.IsEnabled()) {
		logger.Separator("UUID Mapping Report");

		if (horizonMonitor.IsEnabled()) {
			logger.Info(StringFormat("Monitor | account: %s", horizonMonitor.GetAccountUuid()));

			for (int i = 0; i < ArraySize(assets); i++) {
				if (!assets[i].IsEnabled()) {
					continue;
				}

				string symbolName = assets[i].GetSymbol();
				logger.Info(StringFormat("Monitor | asset: %s -> %s", symbolName, horizonMonitor.GetAssetUuid(symbolName)));

				for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
					ulong magic = assets[i].GetStrategyAtIndex(j).GetMagicNumber();
					string stratName = assets[i].GetStrategyAtIndex(j).GetName();
					logger.Info(StringFormat("Monitor | strategy: %s (%llu) -> %s", stratName, magic, horizonMonitor.GetStrategyUuid(magic)));
				}
			}
		}

		if (horizonGateway.IsEnabled()) {
			logger.Info(StringFormat("Gateway | account: %s", horizonGateway.GetAccountUuid()));

			for (int i = 0; i < ArraySize(assets); i++) {
				if (!assets[i].IsEnabled()) {
					continue;
				}

				string symbolName = assets[i].GetSymbol();
				logger.Info(StringFormat("Gateway | asset: %s -> %s", symbolName, horizonGateway.GetAssetUuid(symbolName)));

				for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
					ulong magic = assets[i].GetStrategyAtIndex(j).GetMagicNumber();
					string stratName = assets[i].GetStrategyAtIndex(j).GetName();
					logger.Info(StringFormat("Gateway | strategy: %s (%llu) -> %s", stratName, magic, horizonGateway.GetStrategyUuid(magic)));
				}
			}
		}

		logger.Separator("End UUID Mapping Report");
	}

	logger.Info("Horizon EA started | built " + (string)__DATETIME__);

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

		if (SELogger::GetGlobalEntryCount() > 0) {
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
	}

	if (isStartDay) {
		lastCheckedDay = now.dayOfYear;

		if (tradingStatus.isPaused
		    && tradingStatus.reason != TRADING_PAUSE_REASON_HORIZON_API_REQUEST
		    && tradingStatus.reason != TRADING_PAUSE_REASON_ACCOUNT_INACTIVE
		    && tradingStatus.reason != TRADING_PAUSE_REASON_SERVICES_DOWN) {
			logger.Info("Trading pause cleared - new day started");
			tradingStatus.isPaused = false;
			tradingStatus.reason = TRADING_PAUSE_REASON_NONE;
		}

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].OnStartDay();
		}
	}

	if (isStartHour) {
		lastCheckedHour = now.hour;

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].OnStartHour();
		}
	}

	if (isStartMinute) {
		lastCheckedMinute = now.minute;

		if (SEMessageBus::IsActive()) {
			CheckServiceHealth();
		}

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].OnStartMinute();
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
		horizonMonitor.SyncAccount(assets, ArraySize(assets));
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
		logger.Warning(StringFormat(
			"OnTradeTransaction: Order not found with positionId=%llu",
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
		logger.Warning(StringFormat(
			"OnTradeTransaction: Order not found with orderId=%llu",
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
