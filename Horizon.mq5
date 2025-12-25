#property copyright "Horizon, by Pedro Carvajal"
#property version "1.00"
#property description "Horizon is an advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization. Built for professional traders seeking systematic, data-driven market execution with robust risk management."
#property description "Horizon is developed with MQL5."

#include "enums/EPortfolioAllocationFormula.mqh"
#include "enums/EEquityAtRiskMode.mqh"

input group "General Settings";
input ENUM_ORDER_TYPE_FILLING FillingMode = ORDER_FILLING_IOC; // [1] > Order filling mode

input group "Risk management";
input ENUM_EQUITY_AT_RISK_MODE EquityAtRiskMode = EQUITY_AT_RISK_LOT; // [1] > Equity at risk mode
input bool EquityAtRiskCompounded = true; // [1] > Equity at risk compounded
input double EquityAtRiskBasedOn = 100000.0; // [1] > Equity at risk based on Balance
input double EquityAtRisk = 1; // [1] > Equity at risk value
input bool EquityAtRiskMultiplyByStrategy = false; // [1] > Equity at risk value multiply by strategy
input ENUM_PORTFOLIO_ALLOCATION_FORMULA PortfolioAllocationFormula = ALLOCATION_EQUAL_WEIGHT; // [1] > Portfolio allocation formula

#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SEReportOfOrderHistory/SEReportOfOrderHistory.mqh"
#include "services/SEOrderPersistence/SEOrderPersistence.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HDeleteOldOrders.mqh"

#include "assets/Asset.mqh"

SEDateTime dtime;
SELogger hlogger;
EOrder orders[];
EOrder ordersQueue[];
EOrder closedOrders[];
SEReportOfOrderHistory *orderHistoryReporter;
SEOrderPersistence *orderPersistence;

int lastCheckedDay = -1;
int lastCheckedHour = -1;
int lastCheckedMonth = -1;
int lastCheckedWeek = -1;
int lastStartWeekYday = -1;
int lastEndWeekYday = -1;

// ------------------------------
// Assets
// ------------------------------
#include "assets/XAUUSD.mqh"

SEAsset *xauusd = new XAUUSD();

SEAsset *assets[] = {
	xauusd
};

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

	orderHistoryReporter = new SEReportOfOrderHistory(timestampedReportsDir, true);
	orderPersistence = new SEOrderPersistence();

	// Initialize assets
	int assetCount = ArraySize(assets);

	if (assetCount == 0) {
		hlogger.warning("No assets are defined.");
		return INIT_FAILED;
	}

	double balancePerAsset = AccountInfoDouble(ACCOUNT_BALANCE) / assetCount;

	for (int i = 0; i < assetCount; i++) {
		assets[i].SetBalance(balancePerAsset);
		int result = assets[i].OnInit();

		if (result != INIT_SUCCEEDED)
			return INIT_FAILED;
	}

	// Restore orders from JSON files
	if (isLiveTrading() && CheckPointer(orderPersistence) != POINTER_INVALID) {
		int totalRestored = 0;
		bool restorationFailed = false;

		for (int i = 0; i < ArraySize(assets); i++) {
			for (int s = 0; s < ArraySize(assets[i].assetStrategies); s++) {
				string strategyName = assets[i].assetStrategies[s].GetPrefix();
				hlogger.info("Processing strategy: " + strategyName);

				EOrder restoredOrders[];
				int restoredCount = orderPersistence.LoadOrdersFromJson(strategyName, restoredOrders);

				if (restoredCount == -1) {
					hlogger.error("CRITICAL ERROR: Failed to restore orders for strategy: " + strategyName);
					hlogger.error("This includes JSON deserialization errors and file access problems.");
					restorationFailed = true;
					break;
				}

				for (int j = 0; j < restoredCount; j++) {
					bool isDuplicate = false;
					string restoredId = restoredOrders[j].Id();

					for (int k = 0; k < ArraySize(orders); k++) {
						if (orders[k].Id() == restoredId) {
							isDuplicate = true;
							hlogger.debug("Skipping duplicate order: " + restoredId);
							break;
						}
					}

					if (!isDuplicate) {
						ArrayResize(orders, ArraySize(orders) + 1);
						orders[ArraySize(orders) - 1] = restoredOrders[j];
						orders[ArraySize(orders) - 1].OnInit();

						totalRestored++;
						assets[i].OnOpenOrder(orders[ArraySize(orders) - 1]);
					}
				}
			}

			if (restorationFailed)
				break;
		}

		// Check if restoration failed
		if (restorationFailed) {
			hlogger.error("CRITICAL ERROR: Order restoration failed!");
			hlogger.error("Expert Advisor cannot start safely with corrupted or inaccessible order data.");
			hlogger.error("Please check the JSON files in the Live/ directory or delete them to start fresh.");
			return INIT_FAILED;
		}

		if (totalRestored > 0) {
			hlogger.info("Successfully restored " + IntegerToString(totalRestored) + " orders from JSON files");
			hlogger.info("Orders in array: " + IntegerToString(ArraySize(orders)) + ", open positions in MetaTrader: " + IntegerToString(PositionsTotal()));

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

	for (int i = 0; i < ArraySize(orders); i++)
		orders[i].OnDeinit();

	for (int i = 0; i < ArraySize(ordersQueue); i++)
		ordersQueue[i].OnDeinit();

	for (int i = 0; i < ArraySize(closedOrders); i++)
		closedOrders[i].OnDeinit();

	ArrayResize(orders, 0);
	ArrayFree(orders);
	ArrayResize(ordersQueue, 0);
	ArrayFree(ordersQueue);
	ArrayResize(closedOrders, 0);
	ArrayFree(closedOrders);

	if (CheckPointer(orderHistoryReporter) != POINTER_INVALID)
		delete orderHistoryReporter;

	if (CheckPointer(orderPersistence) != POINTER_INVALID)
		delete orderPersistence;

	for (int i = 0; i < ArraySize(assets); i++)
		if (CheckPointer(assets[i]) != POINTER_INVALID)
			delete assets[i];
}

void OnTimer() {
	if (dtime.Now().hour < 1)
		return;

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
		deleteOldOrders();

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

	for (int i = 0; i < ArraySize(orders); i++) {
		if (!orders[i].isInitialized)
			orders[i].OnInit();

		ENUM_ORDER_STATUSES previousStatus = orders[i].status;

		if (orders[i].status == ORDER_STATUS_PENDING)
			orders[i].CheckToOpen();

		if (previousStatus == ORDER_STATUS_PENDING && orders[i].status == ORDER_STATUS_CANCELLED)
			for (int j = 0; j < ArraySize(assets); j++)
				assets[j].OnOpenOrder(orders[i]);
	}

	for (int i = 0; i < ArraySize(ordersQueue); i++) {
		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = ordersQueue[i];
		hlogger.debug("Recovery order transferred from queue to main orders: " + ordersQueue[i].Id());
	}

	if (ArraySize(ordersQueue) > 0)
		ArrayResize(ordersQueue, 0);
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

				for (int i = 0; i < ArraySize(orders); i++) {
					if (orders[i].orderId == orderId && (orders[i].status == ORDER_STATUS_CLOSING || orders[i].status == ORDER_STATUS_PENDING)) {
						MqlDateTime cancelTime = dtime.Now();
						orders[i].OnClose(cancelTime, 0.0, 0.0, DEAL_REASON_EXPERT);

						for (int j = 0; j < ArraySize(assets); j++)
							assets[j].OnCloseOrder(orders[i], DEAL_REASON_EXPERT);

						hlogger.debug("OnTradeTransaction: Order cancelled with orderId=" + IntegerToString(orderId));
						break;
					}
				}
			}
		}
	}

	if (HistoryDealSelect(transaction.deal)) {
		ulong magic = HistoryDealGetInteger(transaction.deal, DEAL_MAGIC);
		string symbol = HistoryDealGetString(transaction.deal, DEAL_SYMBOL);

		bool validMagic = false;
		for (int i = 0; i < ArraySize(assets); i++) {
			for (int j = 0; j < ArraySize(assets[i].assetStrategies); j++) {
				if (magic == assets[i].assetStrategies[j].GetMagicNumber()) {
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
				int size = ArraySize(orders);
				int idx = -1;

				hlogger.debug("OnTradeTransaction: Closing order with dealId=" + IntegerToString(dealId) + ", positionId=" + IntegerToString(positionId));

				for (int i = 0; i < size; i++) {
					if (orders[i].positionId == positionId) {
						idx = i;
						break;
					}
				}

				if (idx == -1) {
					hlogger.warning("OnTradeTransaction: Order not found with positionId=" + IntegerToString(positionId));
					return;
				}

				orders[idx].OnClose(
					dealTime,
					dealPrice,
					netProfit,
					dealReason
					);

				for (int i = 0; i < ArraySize(assets); i++)
					assets[i].OnCloseOrder(orders[idx], dealReason);

				hlogger.info("OnTradeTransaction: Order closed with positionId=" + IntegerToString(positionId) + ", profit=" + DoubleToString(netProfit, 2));
			} else if (entry == DEAL_ENTRY_IN) {
				int size = ArraySize(orders);
				int idx = -1;

				for (int i = 0; i < size; i++) {
					if (orders[i].orderId == orderId) {
						idx = i;
						break;
					}
				}

				if (idx == -1) {
					hlogger.warning("OnTradeTransaction: Order not found with orderId=" + IntegerToString(orderId));
					return;
				}

				orders[idx].OnOpen(result);

				for (int j = 0; j < ArraySize(assets); j++)
					assets[j].OnOpenOrder(orders[idx]);

				hlogger.debug("OnTradeTransaction: Updated order with dealId=" + IntegerToString(dealId) + ", positionId=" + IntegerToString(positionId));
			}
		}
	}
}

double OnTester() {
	double quality = 1.0;

	for (int i = 0; i < ArraySize(assets); i++) {
		double assetQuality = assets[i].GetQualityProduct();

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
