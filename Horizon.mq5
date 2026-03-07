#property copyright "Horizon5, by Pedro Carvajal"
#property version "1.12"
#property description "Advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization."

#include "enums/EDebugLevel.mqh"
#include "structs/STradingStatus.mqh"

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

input group "HorizonAPI Integration";
input bool EnableHorizonAPI = true; // [1] > Enable HorizonAPI integration
input string HorizonAPIUrl = ""; // [1] > HorizonAPI base URL
input string HorizonAPIKey = ""; // [1] > HorizonAPI key (required)
input int HorizonAPIMaxEventsPerPoll = 10; // [1] > Max events per ConsumeEvents call
input int HorizonAPIEventPollInterval = 3; // [1] > Event poll interval in seconds (0 = every tick)

#include <Trade/Trade.mqh>

#include "configs/Assets.mqh"
#include "constants/time.mqh"
#include "helpers/HGetPipSize.mqh"
#include "helpers/HGetPipValue.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"
#include "integrations/HorizonAPI/HorizonAPI.mqh"
SEDateTime dtime;
SELogger hlogger;
HorizonAPI horizonAPI;
STradingStatus tradingStatus;

int lastCheckedDay = -1;
int lastCheckedHour = -1;
int lastCheckedMinute = -1;
datetime lastTickTime = 0;

int OnInit() {
	EventSetTimer(1);

	// Variables
	dtime = SEDateTime();

	hlogger.SetPrefix("Horizon");
	SELogger::SetGlobalDebugLevel(DebugLevel);

	if (!horizonAPI.Initialize(HorizonAPIUrl, HorizonAPIKey, EnableHorizonAPI && IsLiveTrading())) {
		return INIT_FAILED;
	}

	if (horizonAPI.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(horizonAPI));
	}

	lastCheckedDay = dtime.Today().dayOfYear;
	lastCheckedHour = dtime.Today().hour;

	// Initialize assets
	int assetCount = ArraySize(assets);
	int enabledAssetCount = 0;

	if (assetCount == 0) {
		hlogger.Warning("No assets are defined.");
		return INIT_FAILED;
	}

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled()) {
			enabledAssetCount++;
		}
	}

	if (enabledAssetCount == 0) {
		hlogger.Error("No assets are enabled.");
		hlogger.Error("Enable at least one asset to start.");
		return INIT_FAILED;
	}

	double weightPerAsset = 1.0 / enabledAssetCount;

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled()) {
			assets[i].SetWeight(weightPerAsset);
			assets[i].SetBalance(AccountInfoDouble(ACCOUNT_BALANCE) * weightPerAsset);
		}

		int result = assets[i].OnInit();

		if (result != INIT_SUCCEEDED) {
			return INIT_FAILED;
		}
	}

	ulong magicNumbers[];
	string magicSources[];

	for (int i = 0; i < assetCount; i++) {
		for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
			ulong currentMagic = assets[i].GetStrategyAtIndex(j).GetMagicNumber();
			string currentSource = StringFormat("%s/%s",
				assets[i].GetSymbol(),
				assets[i].GetStrategyAtIndex(j).GetPrefix());

			for (int k = 0; k < ArraySize(magicNumbers); k++) {
				if (magicNumbers[k] == currentMagic) {
					hlogger.Error(StringFormat(
						"Duplicate magic number detected: %llu",
						currentMagic
					));

					hlogger.Error(StringFormat(
						"Conflict between: %s and %s",
						magicSources[k],
						currentSource
					));

					return INIT_FAILED;
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
		hlogger.Error(
			"No strategies enabled. Enable at least one strategy to start."
		);

		return INIT_FAILED;
	}

	hlogger.Info("Horizon EA started | built " + (string)__DATETIME__);

	if (horizonAPI.IsEnabled()) {
		horizonAPI.UpsertAccount();

		SHorizonAccount remoteAccount = horizonAPI.FetchAccount();

		if (!remoteAccount.IsActive()) {
			hlogger.Warning("Account is inactive — trading paused.");
			tradingStatus.isPaused = true;
			tradingStatus.reason = TRADING_PAUSE_REASON_ACCOUNT_INACTIVE;
		}
	}

	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
	EventKillTimer();

	if (reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS) {
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

	if (reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS) {
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

	if (isStartDay) {
		lastCheckedDay = now.dayOfYear;

		if (tradingStatus.isPaused
		    && tradingStatus.reason != TRADING_PAUSE_REASON_HORIZON_API_REQUEST
		    && tradingStatus.reason != TRADING_PAUSE_REASON_ACCOUNT_INACTIVE) {
			hlogger.Info("Trading pause cleared - new day started");
			tradingStatus.isPaused = false;
			tradingStatus.reason = TRADING_PAUSE_REASON_NONE;
		}
	}

	if (isStartHour) {
		lastCheckedHour = now.hour;
	}

	if (isStartMinute) {
		lastCheckedMinute = now.minute;
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnTimer();
	}

	if (isTickInterval) {
		lastTickTime = now.timestamp;

		for (int i = 0; i < ArraySize(assets); i++) {
			if (isStartDay) {
				assets[i].OnStartDay();
			}

			if (isStartHour) {
				assets[i].OnStartHour();
			}

			if (isStartMinute) {
				assets[i].OnStartMinute();
			}

			assets[i].OnTick();
		}
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].ProcessOrders();
	}

	if (isStartHour && horizonAPI.IsEnabled()) {
		horizonAPI.UpsertAccount();

		double totalDrawdownPct = 0;
		double totalDailyPnl = 0;
		double totalFloatingPnl = 0;
		int totalOpenOrderCount = 0;
		double totalExposureLots = 0;

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].SyncToHorizonAPI();
			assets[i].AggregateSnapshotData(
				totalDrawdownPct,
				totalDailyPnl,
				totalFloatingPnl,
				totalOpenOrderCount,
				totalExposureLots
			);
		}

		horizonAPI.StoreAccountSnapshot(
			totalDrawdownPct,
			totalDailyPnl,
			totalFloatingPnl,
			totalOpenOrderCount,
			totalExposureLots
		);
	}
}

void OnTradeTransaction(
	const MqlTradeTransaction &transaction,
	const MqlTradeRequest &request,
	const MqlTradeResult &result
) {
	if (transaction.type == TRADE_TRANSACTION_HISTORY_ADD) {
		if (HistoryOrderSelect(transaction.order)) {
			ulong orderState = HistoryOrderGetInteger(
				transaction.order,
				ORDER_STATE
			);

			if (orderState == 2) {
				ulong orderId = transaction.order;
				int strategyIndex = -1;
				int orderIndex = -1;

				for (int i = 0; i < ArraySize(assets); i++) {
					if (assets[i].FindOrderByOrderId(
						orderId,
						strategyIndex,
						orderIndex
					    )) {
						EOrder *order =
							assets[i].GetStrategyAtIndex(strategyIndex).GetOrderAtIndex(
								orderIndex
							);

						if (
							order != NULL &&
							(
								order.GetStatus() == ORDER_STATUS_CLOSING ||
								order.GetStatus() == ORDER_STATUS_PENDING
							)
						) {
							SDateTime cancelTime = dtime.Now();
							order.OnClose(
								cancelTime,
								0.0,
								0.0,
								DEAL_REASON_EXPERT
							);

							assets[i].GetStrategyAtIndex(strategyIndex).OnCloseOrder(
								order,
								DEAL_REASON_EXPERT
							);
						}

						break;
					}
				}
			}
		}
	}

	if (HistoryDealSelect(transaction.deal)) {
		ulong magic = HistoryDealGetInteger(transaction.deal, DEAL_MAGIC);
		string dealSymbol = HistoryDealGetString(transaction.deal, DEAL_SYMBOL);

		bool isValidMagic = false;

		for (int i = 0; i < ArraySize(assets); i++) {
			for (int j = 0; j < assets[i].GetStrategyCount(); j++) {
				if (magic == assets[i].GetStrategyAtIndex(j).GetMagicNumber()) {
					isValidMagic = true;
					break;
				}
			}

			if (isValidMagic) {
				break;
			}
		}

		if (!isValidMagic && magic != 0) {
			return;
		}

		if (transaction.type == TRADE_TRANSACTION_DEAL_ADD) {
			int entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
				transaction.deal,
				DEAL_ENTRY
			);

			int reason = (int)HistoryDealGetInteger(
				transaction.deal,
				DEAL_REASON
			);

			string comment = HistoryDealGetString(
				transaction.deal,
				DEAL_COMMENT
			);

			ulong positionId = transaction.position;
			ulong orderId = transaction.order;
			ulong dealId = transaction.deal;



			if (entry == DEAL_ENTRY_OUT) {
				SDateTime dealTime = dtime.Now();
				double dealPrice = HistoryDealGetDouble(dealId, DEAL_PRICE);
				double dealProfit = HistoryDealGetDouble(dealId, DEAL_PROFIT);
				double dealCommission = HistoryDealGetDouble(dealId, DEAL_COMMISSION);
				double dealSwap = HistoryDealGetDouble(dealId, DEAL_SWAP);
				double netProfit = dealProfit + (dealCommission * 2) + dealSwap;
				ENUM_DEAL_REASON dealReason =
					(ENUM_DEAL_REASON)HistoryDealGetInteger(
						dealId,
						DEAL_REASON
					);


				int strategyIndex = -1;
				int orderIndex = -1;
				bool isFound = false;

				for (int i = 0; i < ArraySize(assets); i++) {
					if (
						assets[i].FindOrderByPositionId(positionId,
							strategyIndex,
							orderIndex
						)) {
						EOrder *order =
							assets[i].GetStrategyAtIndex(strategyIndex).GetOrderAtIndex(
								orderIndex
							);

						if (order != NULL) {
							order.SetGrossProfit(dealProfit);
							order.SetCommission(dealCommission);
							order.SetSwap(dealSwap);
							order.OnClose(dealTime, dealPrice, netProfit, dealReason);
							assets[i].GetStrategyAtIndex(strategyIndex).OnCloseOrder(order, dealReason);

							hlogger.Info(StringFormat(
								"OnTradeTransaction: Order closed with positionId=%llu, profit=%.2f",
								positionId,
								netProfit
							));

							isFound = true;
						}

						break;
					}
				}

				if (!isFound) {
					hlogger.Warning(StringFormat(
						"OnTradeTransaction: Order not found with positionId=%llu",
						positionId
					));
				}
			} else if (entry == DEAL_ENTRY_IN) {
				int strategyIndex = -1;
				int orderIndex = -1;
				bool isFound = false;

				for (int i = 0; i < ArraySize(assets); i++) {
					if (
						assets[i].FindOrderByOrderId(
							orderId,
							strategyIndex,
							orderIndex
						)) {
						EOrder *order =
							assets[i].GetStrategyAtIndex(strategyIndex).GetOrderAtIndex(
								orderIndex
							);

						if (order != NULL) {
							if (order.GetStatus() != ORDER_STATUS_OPEN) {
								MqlTradeResult openResult;
								ZeroMemory(openResult);
								openResult.deal = dealId;
								openResult.order = orderId;
								openResult.price = HistoryDealGetDouble(dealId, DEAL_PRICE);
								openResult.retcode = TRADE_RETCODE_DONE;
								order.OnOpen(openResult);
							}

							assets[i].GetStrategyAtIndex(strategyIndex).OnOpenOrder(
								order
							);


							isFound = true;
						}

						break;
					}
				}

				if (!isFound) {
					hlogger.Warning(StringFormat(
						"OnTradeTransaction: Order not found with orderId=%llu",
						orderId
					));
				}
			}
		}
	}
}

double OnTester() {
	double quality = 1.0;

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].PerformStatistics();
		double assetQuality = assets[i].CalculateQualityProduct();

		if (assetQuality == 0) {
			quality = 0;
		} else {
			quality = MathPow(quality * assetQuality, 1.0 / 2.0);
		}
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].ExportOrderHistory();
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].ExportStrategySnapshots();
	}

	for (int i = 0; i < ArraySize(assets); i++) {
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
