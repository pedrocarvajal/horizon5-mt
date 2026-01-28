#property copyright "Horizon, by Pedro Carvajal"
#property version "1.00"
#property description "Horizon is an advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization. Built for professional traders seeking systematic, data-driven market execution with robust risk management."
#property description "Horizon is developed with MQL5."

input group "General Settings";
input ENUM_ORDER_TYPE_FILLING FillingMode = ORDER_FILLING_IOC; // [1] > Order filling mode

input group "Reporting";
input bool EnableOrderHistoryReport = false; // [1] > Enable order history report on tester

input group "Risk management";
input bool EquityAtRiskCompounded = true; // [1] > Equity at risk compounded
input double EquityAtRisk = 10; // [1] > Equity at risk value (in percentage)

#include <Trade/Trade.mqh>
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SEReportOfOrderHistory/SEReportOfOrderHistory.mqh"
#include "services/SEOrderPersistence/SEOrderPersistence.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HIsMarketClosed.mqh"
#include "helpers/HGetPipSize.mqh"
#include "helpers/HGetPipValue.mqh"

#include "constants/time.mqh"

#include "configs/Assets.mqh"

SEDateTime dtime;
SELogger hlogger;
SEReportOfOrderHistory *orderHistoryReporter;
SEOrderPersistence *orderPersistence;

int lastCheckedDay = -1;
int lastCheckedHour = -1;
int lastCheckedMonth = -1;
int lastCheckedWeek = -1;
int lastStartWeekYday = -1;
int lastEndWeekYday = -1;

int OnInit() {
	EventSetTimer(1);

	// Variables
	dtime = SEDateTime();
	hlogger.SetPrefix("Horizon");

	lastCheckedDay = dtime.Today().day_of_year;
	lastCheckedHour = dtime.Today().hour;
	lastCheckedMonth = dtime.Today().mon;
	lastCheckedWeek = dtime.Now().day_of_week;

	MqlDateTime dt = dtime.Now();
	string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
	string timestampedReportsDir = "/Reports/" + _Symbol + "/" + timestamp;

	if (EnableOrderHistoryReport)
		orderHistoryReporter = new SEReportOfOrderHistory(timestampedReportsDir, true);

	orderPersistence = new SEOrderPersistence();

	// Initialize assets
	int assetCount = ArraySize(assets);

	if (assetCount == 0) {
		hlogger.warning("No assets are defined.");
		return INIT_FAILED;
	}

	double weightPerAsset = 1.0 / assetCount;

	for (int i = 0; i < assetCount; i++) {
		assets[i].SetWeight(weightPerAsset);
		assets[i].SetBalance(AccountInfoDouble(ACCOUNT_BALANCE) * weightPerAsset);

		int result = assets[i].OnInit();

		if (result != INIT_SUCCEEDED)
			return INIT_FAILED;
	}

	ulong magicNumbers[];
	string magicSources[];

	for (int i = 0; i < assetCount; i++) {
		for (int j = 0; j < ArraySize(assets[i].strategies); j++) {
			ulong currentMagic = assets[i].strategies[j].GetMagicNumber();
			string currentSource = assets[i].GetSymbol() + "/" + assets[i].strategies[j].GetPrefix();

			for (int k = 0; k < ArraySize(magicNumbers); k++) {
				if (magicNumbers[k] == currentMagic) {
					hlogger.error("Duplicate magic number detected: " + IntegerToString(currentMagic));
					hlogger.error("Conflict between: " + magicSources[k] + " and " + currentSource);
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
		hlogger.error("No strategies enabled. Enable at least one strategy to start.");
		return INIT_FAILED;
	}

	// Restore orders from JSON files
	if (isLiveTrading() && CheckPointer(orderPersistence) != POINTER_INVALID) {
		int totalRestored = 0;
		bool restorationFailed = false;

		for (int i = 0; i < ArraySize(assets); i++) {
			for (int s = 0; s < ArraySize(assets[i].strategies); s++) {
				SEStrategy *strategy = assets[i].strategies[s];
				string strategyPrefix = strategy.GetPrefix();
				hlogger.info("Processing strategy: " + strategyPrefix);

				EOrder restoredOrders[];
				int restoredCount = orderPersistence.LoadOrdersFromJson(strategyPrefix, restoredOrders);

				if (restoredCount == -1) {
					hlogger.error("CRITICAL ERROR: Failed to restore orders for strategy: " + strategyPrefix);
					hlogger.error("This includes JSON deserialization errors and file access problems.");
					restorationFailed = true;
					break;
				}

				for (int j = 0; j < restoredCount; j++) {
					string restoredId = restoredOrders[j].GetId();
					int existingIndex = strategy.FindOrderIndexById(restoredId);

					if (existingIndex != -1) {
						hlogger.debug("Skipping duplicate order: " + restoredId);
						continue;
					}

					restoredOrders[j].OnInit();
					strategy.AddOrder(restoredOrders[j]);
					totalRestored++;

					EOrder *addedOrder = strategy.GetOrderAtIndex(strategy.GetOrdersCount() - 1);

					if (addedOrder != NULL)
						strategy.OnOpenOrder(addedOrder);
				}
			}

			if (restorationFailed)
				break;
		}

		if (restorationFailed) {
			hlogger.error("CRITICAL ERROR: Order restoration failed!");
			hlogger.error("Expert Advisor cannot start safely with corrupted or inaccessible order data.");
			hlogger.error("Please check the JSON files in the Live/ directory or delete them to start fresh.");
			return INIT_FAILED;
		}

		if (totalRestored > 0) {
			hlogger.info("Successfully restored " + IntegerToString(totalRestored) + " orders from JSON files");
			hlogger.info("Open positions in MetaTrader: " + IntegerToString(PositionsTotal()));
			hlogger.debug("Restored orders for tracking");
		} else {
			hlogger.info("No orders found to restore");
		}
	}

	return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
	EventKillTimer();

	for (int i = 0; i < ArraySize(assets); i++)
		assets[i].OnDeinit();

	if (CheckPointer(orderHistoryReporter) != POINTER_INVALID)
		delete orderHistoryReporter;

	if (CheckPointer(orderPersistence) != POINTER_INVALID)
		delete orderPersistence;

	for (int i = 0; i < ArraySize(assets); i++)
		if (CheckPointer(assets[i]) != POINTER_INVALID)
			delete assets[i];
}

void OnTimer() {
	// Start of week (Monday) - executed FIRST
	if (dtime.Now().day_of_week == 1 && lastStartWeekYday != dtime.Now().day_of_year) {
		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].OnStartWeek();

		lastStartWeekYday = dtime.Now().day_of_year;
	}

	// End of week (Friday 23:00 or later) - executed BEFORE daily/hourly triggers
	if (dtime.Now().day_of_week == 5 && dtime.Now().hour >= 23 && lastEndWeekYday != dtime.Now().day_of_year) {
		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].OnEndWeek();

		lastEndWeekYday = dtime.Now().day_of_year;
	}

	// Start of new day
	if (dtime.Now().day_of_year != lastCheckedDay) {
		lastCheckedDay = dtime.Now().day_of_year;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].CleanupClosedOrders();

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].OnStartDay();
	}

	// Start of new hour
	if (dtime.Now().hour != lastCheckedHour) {
		lastCheckedHour = dtime.Now().hour;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].OnStartHour();
	}

	// Start of new month
	if (dtime.Now().mon != lastCheckedMonth) {
		lastCheckedMonth = dtime.Now().mon;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].OnStartMonth();
	}

	// Start of new minute
	static int lastCheckedMinute = -1;
	if (dtime.Now().min != lastCheckedMinute) {
		lastCheckedMinute = dtime.Now().min;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].OnStartMinute();
	}

	// Per-tick processing
	for (int i = 0; i < ArraySize(assets); i++)
		assets[i].OnTick();

	for (int i = 0; i < ArraySize(assets); i++)
		assets[i].ProcessOrders();
}

void OnTradeTransaction(
	const MqlTradeTransaction &transaction,
	const MqlTradeRequest &request,
	const MqlTradeResult &result
	) {
	if (transaction.type == TRADE_TRANSACTION_HISTORY_ADD) {
		if (HistoryOrderSelect(transaction.order)) {
			ulong orderState = HistoryOrderGetInteger(transaction.order, ORDER_STATE);

			if (orderState == 2) {
				ulong orderId = transaction.order;
				int strategyIndex = -1;
				int orderIndex = -1;

				for (int i = 0; i < ArraySize(assets); i++) {
					if (assets[i].FindOrderByOrderId(orderId, strategyIndex, orderIndex)) {
						EOrder *order = assets[i].strategies[strategyIndex].GetOrderAtIndex(orderIndex);

						if (order != NULL && (order.GetStatus() == ORDER_STATUS_CLOSING || order.GetStatus() == ORDER_STATUS_PENDING)) {
							MqlDateTime cancelTime = dtime.Now();
							order.OnClose(cancelTime, 0.0, 0.0, DEAL_REASON_EXPERT);
							assets[i].strategies[strategyIndex].OnCloseOrder(order, DEAL_REASON_EXPERT);
							hlogger.debug("OnTradeTransaction: Order cancelled with orderId=" + IntegerToString(orderId));
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

		bool validMagic = false;

		for (int i = 0; i < ArraySize(assets); i++) {
			for (int j = 0; j < ArraySize(assets[i].strategies); j++) {
				if (magic == assets[i].strategies[j].GetMagicNumber()) {
					validMagic = true;
					break;
				}
			}

			if (validMagic)
				break;
		}

		if (!validMagic && magic != 0)
			return;

		if (transaction.type == TRADE_TRANSACTION_DEAL_ADD) {
			int entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
			int reason = (int)HistoryDealGetInteger(transaction.deal, DEAL_REASON);
			string comment = HistoryDealGetString(transaction.deal, DEAL_COMMENT);
			ulong positionId = transaction.position;
			ulong orderId = transaction.order;
			ulong dealId = transaction.deal;

			hlogger.debug("OnTradeTransaction: comment=" + comment + ", positionId=" + IntegerToString(positionId) + ", orderId=" + IntegerToString(orderId) + ", dealId=" + IntegerToString(dealId));
			hlogger.debug("OnTradeTransaction: entry=" + IntegerToString(entry) + ", reason=" + IntegerToString(reason));

			if (entry == DEAL_ENTRY_OUT) {
				MqlDateTime dealTime = dtime.Now();
				double dealPrice = HistoryDealGetDouble(dealId, DEAL_PRICE);
				double dealProfit = HistoryDealGetDouble(dealId, DEAL_PROFIT);
				double dealCommission = HistoryDealGetDouble(dealId, DEAL_COMMISSION);
				double dealSwap = HistoryDealGetDouble(dealId, DEAL_SWAP);
				double netProfit = dealProfit + (dealCommission * 2) + dealSwap;
				ENUM_DEAL_REASON dealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealId, DEAL_REASON);

				hlogger.debug("OnTradeTransaction: Closing order with dealId=" + IntegerToString(dealId) + ", positionId=" + IntegerToString(positionId));

				int strategyIndex = -1;
				int orderIndex = -1;
				bool found = false;

				for (int i = 0; i < ArraySize(assets); i++) {
					if (assets[i].FindOrderByPositionId(positionId, strategyIndex, orderIndex)) {
						EOrder *order = assets[i].strategies[strategyIndex].GetOrderAtIndex(orderIndex);

						if (order != NULL) {
							order.OnClose(dealTime, dealPrice, netProfit, dealReason);
							assets[i].strategies[strategyIndex].OnCloseOrder(order, dealReason);
							hlogger.info("OnTradeTransaction: Order closed with positionId=" + IntegerToString(positionId) + ", profit=" + DoubleToString(netProfit, 2));
							found = true;
						}

						break;
					}
				}

				if (!found)
					hlogger.warning("OnTradeTransaction: Order not found with positionId=" + IntegerToString(positionId));
			} else if (entry == DEAL_ENTRY_IN) {
				int strategyIndex = -1;
				int orderIndex = -1;
				bool found = false;

				for (int i = 0; i < ArraySize(assets); i++) {
					if (assets[i].FindOrderByOrderId(orderId, strategyIndex, orderIndex)) {
						EOrder *order = assets[i].strategies[strategyIndex].GetOrderAtIndex(orderIndex);

						if (order != NULL) {
							if (order.GetStatus() != ORDER_STATUS_OPEN) {
								MqlTradeResult openResult;
								ZeroMemory(openResult);
								openResult.deal = dealId;
								openResult.order = orderId;
								openResult.price = HistoryDealGetDouble(dealId, DEAL_PRICE);
								openResult.retcode = 10009;
								order.OnOpen(openResult);
							}

							assets[i].strategies[strategyIndex].OnOpenOrder(order);
							hlogger.debug("OnTradeTransaction: Updated order with dealId=" + IntegerToString(dealId) + ", positionId=" + IntegerToString(positionId));
							found = true;
						}

						break;
					}
				}

				if (!found)
					hlogger.warning("OnTradeTransaction: Order not found with orderId=" + IntegerToString(orderId));
			}
		}
	}
}

double OnTester() {
	double quality = 1.0;

	for (int i = 0; i < ArraySize(assets); i++) {
		double assetQuality = assets[i].CalculateQualityProduct();

		if (assetQuality == 0)
			quality = 0;
		else
			quality = MathPow(quality * assetQuality, 1.0 / 2.0);
	}

	if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
		orderHistoryReporter.PrintCurrentPath();
		orderHistoryReporter.ExportOrderHistoryToJsonFile();
		hlogger.info("Order history exported with " + IntegerToString(orderHistoryReporter.GetOrderCount()) + " orders");
	}

	return quality;
}

int OnTesterInit() {
	for (int i = 0; i < ArraySize(assets); i++)
		assets[i].OnTesterInit();

	return INIT_SUCCEEDED;
}

void OnTesterPass() {
}

void OnTesterDeinit() {
}
