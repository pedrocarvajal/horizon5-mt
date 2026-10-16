#property copyright "Horizon5, by Pedro Carvajal"
#property version "0.420"
#property description "Advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization."

#include <Trade/Trade.mqh>

#include "configs/Assets.mqh"

#include "constants/COHorizon.mqh"

#include "entities/EAccount.mqh"

#include "enums/EDebugLevel.mqh"

#include "helpers/HGetLogsPath.mqh"

#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"
#include "services/SRAccountAuditor/SRAccountAuditor.mqh"

EAccount account;
SEDateTime dtime;
SELogger logger;
SRAccountAuditor accountAuditor;

input group "General Settings";
input int TickIntervalTime = 60; // [1] > Tick interval (1 = 1 second by tick)
input ENUM_ORDER_TYPE_FILLING FillingMode = ORDER_FILLING_IOC; // [1] > Order filling mode
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "Reporting > Strategy Reports";
input bool EnableOrderHistoryReport = false; // [1] > Export per-strategy order history
input bool EnableSnapshotHistoryReport = false; // [1] > Export per-strategy snapshots
input bool EnableMarketHistoryReport = false; // [1] > Export per-asset market snapshots

input group "Reporting > Logs";
input bool EnableLogExport = false; // [1] > Export portfolio logs on shutdown

input group "Risk management";
input bool EquityAtRiskCompounded = false; // [1] > Equity at risk compounded
input double EquityAtRisk = 1; // [1] > Equity at risk value (in percentage)

int lastCheckedDay = -1;
int lastCheckedHour = -1;
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

int OnInit() {
	EventSetTimer(1);

	dtime = SEDateTime();
	logger.SetPrefix("Horizon");

	SELogger::SetGlobalDebugLevel(DebugLevel);

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

	logger.Info(
		LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
		"service started | system=Horizon version=0.420 built='2026-10-16 21:10:35'"
	);

	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
	EventKillTimer();

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
	bool isTickInterval = (now.timestamp - lastTickTime) >= TickIntervalTime;

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnTimer();
		assets[i].ProcessBarEvents();
	}

	if (isStartDay) {
		lastCheckedDay = now.dayOfYear;

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].ResumeTrading();
		}
	}

	if (isStartHour) {
		lastCheckedHour = now.hour;
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
			ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)HistoryOrderGetInteger(transaction.order, ORDER_STATE);

			if (orderState == ORDER_STATE_CANCELED || orderState == ORDER_STATE_EXPIRED) {
				for (int i = 0; i < ArraySize(assets); i++) {
					if (assets[i].HandleOrderCancellation(transaction.order, orderState)) {
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
			positionId, dealTime, dealPrice, netProfit, dealReason
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
