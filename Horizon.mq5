#property copyright "Horizon, by Pedro Carvajal"
#property version "1.00"
#property description "Advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization."

input group "General Settings";
input int TickIntervalTime = 60; // [1] > Tick interval (1 = 1 second by tick)
input ENUM_ORDER_TYPE_FILLING FillingMode = ORDER_FILLING_IOC; // [1] > Order filling mode
input group "Reporting";
input bool EnableOrderHistoryReport = false; // [1] > Enable order history report on tester
input bool EnableSnapshotHistoryReport = false; // [1] > Enable snapshot history report on tester
input bool EnableMarketHistoryReport = false; // [1] > Enable market history report on tester

input group "Risk management";
input bool EquityAtRiskCompounded = false; // [1] > Equity at risk compounded
input double EquityAtRisk = 1; // [1] > Equity at risk value (in percentage)

input group "Strategy Allocator";
input bool EnableStrategyAllocator = false; // [1] > Enable KNN strategy allocator
input int AllocatorRollingWindow = 150; // [1] > Rolling window for feature computation (days)
input int AllocatorNormalizationWindow = 365; // [1] > Normalization window for z-score (days)
input int AllocatorKNeighbors = 20; // [1] > Number of KNN neighbors
input int AllocatorMaxActiveStrategies = 10; // [1] > Maximum active strategies
input double AllocatorScoreThreshold = 0.001; // [1] > Minimum score to activate strategy
input int AllocatorForwardWindow = 4; // [1] > Forward performance window (days)

#include <Trade/Trade.mqh>

#include "configs/Assets.mqh"
#include "constants/time.mqh"
#include "helpers/HGetPipSize.mqh"
#include "helpers/HGetPipValue.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
SEDateTime dtime;
SELogger hlogger;

int lastCheckedDay = -1;
int lastCheckedHour = -1;
int lastCheckedMinute = -1;

int OnInit() {
	EventSetTimer(TickIntervalTime);

	// Variables
	dtime = SEDateTime();

	hlogger.SetPrefix("Horizon");

	lastCheckedDay = dtime.Today().dayOfYear;
	lastCheckedHour = dtime.Today().hour;

	// Initialize assets
	int assetCount = ArraySize(assets);
	int enabledAssetCount = 0;

	if (assetCount == 0) {
		hlogger.warning("No assets are defined.");
		return INIT_FAILED;
	}

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled())
			enabledAssetCount++;
	}

	if (enabledAssetCount == 0) {
		hlogger.error("No assets are enabled.");
		hlogger.error("Enable at least one asset to start.");
		return INIT_FAILED;
	}

	double weightPerAsset = 1.0 / enabledAssetCount;

	for (int i = 0; i < assetCount; i++) {
		if (assets[i].IsEnabled()) {
			assets[i].SetWeight(weightPerAsset);
			assets[i].SetBalance(AccountInfoDouble(ACCOUNT_BALANCE) * weightPerAsset);
		}

		int result = assets[i].OnInit();

		if (result != INIT_SUCCEEDED)
			return INIT_FAILED;
	}

	ulong magicNumbers[];
	string magicSources[];

	for (int i = 0; i < assetCount; i++) {
		for (int j = 0; j < ArraySize(assets[i].strategies); j++) {
			ulong currentMagic = assets[i].strategies[j].GetMagicNumber();
			string currentSource = StringFormat("%s/%s",
				assets[i].GetSymbol(),
				assets[i].strategies[j].GetPrefix());

			for (int k = 0; k < ArraySize(magicNumbers); k++) {
				if (magicNumbers[k] == currentMagic) {
					hlogger.error(StringFormat(
						"Duplicate magic number detected: %llu",
						currentMagic
					));

					hlogger.error(StringFormat(
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
		hlogger.error(
			"No strategies enabled. Enable at least one strategy to start."
		);

		return INIT_FAILED;
	}

	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
	EventKillTimer();

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnDeinit();
	}

	if (reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS) {
		for (int i = 0; i < ArraySize(assets); i++) {
			if (CheckPointer(assets[i]) != POINTER_INVALID)
				delete assets[i];
		}
	}
}

void OnTimer() {
	SDateTime now = dtime.Now();

	bool isStartDay = (now.dayOfYear != lastCheckedDay);
	bool isStartHour = (now.hour != lastCheckedHour);
	bool isStartMinute = (now.minute != lastCheckedMinute);

	if (isStartDay) lastCheckedDay = now.dayOfYear;
	if (isStartHour) lastCheckedHour = now.hour;
	if (isStartMinute) lastCheckedMinute = now.minute;

	for (int i = 0; i < ArraySize(assets); i++) {
		assets[i].OnTimer();

		if (isStartDay) {
			assets[i].CleanupClosedOrders();
			assets[i].OnStartDay();
		}

		if (isStartHour) assets[i].OnStartHour();
		if (isStartMinute) assets[i].OnStartMinute();

		assets[i].OnTick();
		assets[i].ProcessOrders();
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
							assets[i].strategies[strategyIndex].GetOrderAtIndex(
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

							assets[i].strategies[strategyIndex].OnCloseOrder(
								order,
								DEAL_REASON_EXPERT
							);

							hlogger.debug(StringFormat(
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
			for (int j = 0; j < ArraySize(assets[i].strategies); j++) {
				if (magic == assets[i].strategies[j].GetMagicNumber()) {
					isValidMagic = true;
					break;
				}
			}

			if (isValidMagic)
				break;
		}

		if (!isValidMagic && magic != 0)
			return;

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

			hlogger.debug(StringFormat(
				"OnTradeTransaction: comment=%s, positionId=%llu, orderId=%llu, dealId=%llu",
				comment,
				positionId,
				orderId,
				dealId
			));

			hlogger.debug(StringFormat(
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

				hlogger.debug(StringFormat(
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
							assets[i].strategies[strategyIndex].GetOrderAtIndex(
								orderIndex
							);

						if (order != NULL) {
							order.OnClose(dealTime, dealPrice, netProfit, dealReason);
							assets[i].strategies[strategyIndex].OnCloseOrder(order, dealReason);

							hlogger.info(StringFormat(
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
					hlogger.warning(StringFormat(
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
							assets[i].strategies[strategyIndex].GetOrderAtIndex(
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

							assets[i].strategies[strategyIndex].OnOpenOrder(
								order
							);

							hlogger.debug(StringFormat(
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
					hlogger.warning(StringFormat(
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

		if (assetQuality == 0)
			quality = 0;
		else
			quality = MathPow(quality * assetQuality, 1.0 / 2.0);
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
