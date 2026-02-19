#property copyright "Horizon5, by Pedro Carvajal"
#property version "1.00"
#property description "Advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization."

#include "enums/EAllocatorMode.mqh"
#include "enums/EDebugLevel.mqh"

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

input group "WARRoom Integration";
input bool EnableWARRoom = true; // [1] > Enable WARRoom API integration
input string WARRoomUrl = "http://127.0.0.1:3001"; // [1] > WARRoom PostgREST API URL
input string WARRoomApiKey = "REDACTED_JWT_TOKEN"; // [1] > WARRoom JWT API key (required)

input group "Strategy Allocator";
input bool EnableStrategyAllocator = false; // [1] > Enable KNN strategy allocator
input ENUM_ALLOCATOR_MODE AllocatorMode = ALLOCATOR_MODE_TRAIN; // [1] > Allocator mode (Train = collect data, Inference = use model)
input string AllocatorModelPath = "Models"; // [1] > Model directory path (in common files)
input int AllocatorRollingWindow = 150; // [1] > Rolling window for feature computation (days)
input int AllocatorNormalizationWindow = 365; // [1] > Normalization window for z-score (days)
input int AllocatorKNeighbors = 20; // [1] > Number of KNN neighbors
input int AllocatorMaxActiveStrategies = 1; // [1] > Maximum active strategies
input double AllocatorScoreThreshold = 0.0; // [1] > Minimum score to activate strategy
input int AllocatorForwardWindow = 4; // [1] > Forward performance window (days)

#include <Trade/Trade.mqh>

#include "configs/Assets.mqh"
#include "constants/time.mqh"
#include "helpers/HGetPipSize.mqh"
#include "helpers/HGetPipValue.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "integrations/WARRoom/WARRoom.mqh"
SEDateTime dtime;
SELogger hlogger;
WARRoom warroom;

int lastCheckedDay = -1;
int lastCheckedHour = -1;
int lastCheckedMinute = -1;

int OnInit() {
	EventSetTimer(TickIntervalTime);

	// Variables
	dtime = SEDateTime();

	hlogger.SetPrefix("Horizon");
	hlogger.SetDebugLevel(DebugLevel);

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
		assets[i].SetDebugLevel(DebugLevel);

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

	if (!warroom.Initialize(WARRoomUrl, WARRoomApiKey, EnableWARRoom && IsLiveTrading())) {
		return INIT_FAILED;
	}

	if (warroom.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(warroom));
	}

	warroom.InsertOrUpdateAccount();
	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
	EventKillTimer();

	if (reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS) {
		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].OnEnd();
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

	if (isStartDay) {
		lastCheckedDay = now.dayOfYear;
	}

	if (isStartHour) {
		lastCheckedHour = now.hour;
	}

	if (isStartMinute) {
		lastCheckedMinute = now.minute;
	}

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnTimer();

		if (isStartDay) {
			assets[i].CleanupClosedOrders();
			assets[i].OnStartDay();
		}

		if (isStartHour) {
			assets[i].OnStartHour();
		}

		if (isStartMinute) {
			assets[i].OnStartMinute();
		}

		assets[i].OnTick();
		assets[i].ProcessOrders();
	}

	if (isStartMinute) {
		warroom.InsertOrUpdateAccount();
		warroom.InsertAccountSnapshot();

		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].SyncToWARRoom();
		}
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

							hlogger.Debug(StringFormat(
								"OnTradeTransaction: Order cancelled with orderId=%llu",
								orderId
							));
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

			hlogger.Debug(StringFormat(
				"OnTradeTransaction: comment=%s, positionId=%llu, orderId=%llu, dealId=%llu",
				comment,
				positionId,
				orderId,
				dealId
			));

			hlogger.Debug(StringFormat(
				"OnTradeTransaction: entry=%d, reason=%d",
				entry,
				reason
			));

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

				hlogger.Debug(StringFormat(
					"OnTradeTransaction: Closing order with dealId=%llu, positionId=%llu",
					dealId,
					positionId
				));

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

							hlogger.Debug(StringFormat(
								"OnTradeTransaction: Updated order with dealId=%llu, positionId=%llu",
								dealId,
								positionId
							));

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

	if (EnableStrategyAllocator && AllocatorMode == ALLOCATOR_MODE_TRAIN) {
		for (int i = 0; i < ArraySize(assets); i++) {
			assets[i].ExportAllocatorModel();
		}
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
