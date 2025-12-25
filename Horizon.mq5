#property copyright "Horizon, by Pedro Carvajal"
#property version "1.00"
#property description "Horizon is an advanced algorithmic trading system for MetaTrader 5 featuring multiple quantitative strategies with intelligent portfolio optimization. Built for professional traders seeking systematic, data-driven market execution with robust risk management."
#property description "Horizon is developed with MQL5."

#include <Trade/Trade.mqh>
#include <Indicators/Trend.mqh>
#include <Indicators/Oscilators.mqh>
#include <Indicators/TimeSeries.mqh>
#include <Indicators/Indicators.mqh>

#include "libraries/json/index.mqh"
#include "services/Logger/Logger.mqh"

#include "enums/EOrderStatuses.mqh"
#include "enums/EPortfolioAllocationFormula.mqh"
#include "enums/ETradingModes.mqh"
#include "enums/EEquityAtRiskMode.mqh"

#include "structs/SOrderHistory.mqh"
#include "structs/SStatisticsSnapshot.mqh"
#include "structs/SQualityThresholds.mqh"
#include "structs/SQualityResult.mqh"

#include "helpers/isMarketClosed.mqh"
#include "helpers/isLiveTrading.mqh"
#include "helpers/deleteOldOrders.mqh"

#include "services/DateTime/DateTime.mqh"
#include "services/Trade/Trade.mqh"
#include "services/Order/Order.mqh"
#include "services/ReportOfOrderHistory/ReportOfOrderHistory.mqh"
#include "services/OrderPersistence/OrderPersistence.mqh"

#include "interfaces/Asset.mqh"
#include "interfaces/Strategy.mqh"

IStrategy *strategies[];
DateTime dtime;
Order orders[];
Order orders_queue[];
Order closed_orders[];
ReportOfOrderHistory *order_history_reporter;
Logger hlogger;

OrderPersistence *order_persistence;

int last_checked_day = -1;
int last_checked_hour = -1;
int last_checked_month = -1;
int last_checked_week = -1;
int last_start_week_yday = -1;
int last_end_week_yday = -1;

input group "General Settings";
input ENUM_ORDER_TYPE_FILLING filling_mode = ORDER_FILLING_IOC; // [1] > Order filling mode

input group "Risk management";
input ENUM_EQUITY_AT_RISK_MODE equity_at_risk_mode = EQUITY_AT_RISK_LOT; // [1] > Equity at risk mode
input bool equity_at_risk_compounded = true; // [1] > Equity at risk compounded
input double equity_at_risk_based_on = 100000.0; // [1] > Equity at risk based on Balance
input double equity_at_risk = 1; // [1] > Equity at risk value
input bool equity_at_risk_multiply_by_strategy = false; // [1] > Equity at risk value multiply by strategy
input ENUM_PORTFOLIO_ALLOCATION_FORMULA portfolio_allocation_formula = ALLOCATION_EQUAL_WEIGHT; // [1] > Portfolio allocation formula

// ------------------------------
// Assets
// ------------------------------
#include "assets/XAUUSD.mqh"

IAsset *xauusd = new XAUUSD();

IAsset *assets[] = { 
	xauusd
};

IStrategy *all_strategies[] = {

};

int OnInit() {
	EventSetTimer(1);

	// Variables
	dtime = DateTime();
	hlogger.SetPrefix("Horizon");

	last_checked_day = dtime.Today().day_of_year;
	last_checked_hour = dtime.Today().hour;
	last_checked_month = dtime.Today().mon;
	last_checked_week = dtime.Now().day_of_week;

	MqlDateTime dt;
	TimeToStruct(TimeCurrent(), dt);
	string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
	string timestamped_reports_dir = "/Reports/" + _Symbol + "/" + timestamp;

	order_history_reporter = new ReportOfOrderHistory(timestamped_reports_dir, true);
	order_persistence = new OrderPersistence();

	// Build all_strategies from assets 
	for (int i = 0; i < ArraySize(assets); i++) {
		for (int j = 0; j < ArraySize(assets[i].asset_strategies); j++) {
			ArrayResize(all_strategies, ArraySize(all_strategies) + 1);
			all_strategies[ArraySize(all_strategies) - 1] = assets[i].asset_strategies[j];
		}
	}

	// Strategies
	for (int i = 0; i < ArraySize(all_strategies); i++) {
		if (all_strategies[i] != NULL) {
			ArrayResize(strategies, ArraySize(strategies) + 1);
			strategies[ArraySize(strategies) - 1] = all_strategies[i];
		}
	}

	if (ArraySize(strategies) == 0) {
		hlogger.warning("No strategies are enabled. Please enable at least one strategy.");
		return INIT_FAILED;
	}

	for (int i = 0; i < ArraySize(strategies); i++) {
		double allocated_balance = AccountInfoDouble(ACCOUNT_BALANCE) / ArraySize(strategies);
		strategies[i].setBalance(allocated_balance);
		int r = strategies[i].onInit();

		if (r != INIT_SUCCEEDED) {
			hlogger.error("Strategy initialization failed: " + strategies[i].prefix);
			return INIT_FAILED;
		}
	}

	// Restore orders from JSON files
	if (isLiveTrading() && CheckPointer(order_persistence) != POINTER_INVALID) {
		int total_restored = 0;
		bool restoration_failed = false;

		for (int i = 0; i < ArraySize(strategies); i++) {
			string strategy_name = strategies[i].prefix;
			hlogger.info("Processing strategy: " + strategy_name);

			Order restored_orders[];
			int restored_count = order_persistence.LoadOrdersFromJson(strategy_name, restored_orders);

			if (restored_count == -1) {
				hlogger.error("CRITICAL ERROR: Failed to restore orders for strategy: " + strategy_name);
				hlogger.error("This includes JSON deserialization errors and file access problems.");
				restoration_failed = true;
				break;
			}

			for (int j = 0; j < restored_count; j++) {
				bool is_duplicate = false;
				string restored_id = restored_orders[j].Id();

				for (int k = 0; k < ArraySize(orders); k++) {
					if (orders[k].Id() == restored_id) {
						is_duplicate = true;
						hlogger.debug("Skipping duplicate order: " + restored_id);
						break;
					}
				}

				if (!is_duplicate) {
					ArrayResize(orders, ArraySize(orders) + 1);
					orders[ArraySize(orders) - 1] = restored_orders[j];
					orders[ArraySize(orders) - 1].onInit();

					total_restored++;
					strategies[i].onOpenOrder(orders[ArraySize(orders) - 1]);
				}
			}
		}

		// Check if restoration failed
		if (restoration_failed) {
			hlogger.error("CRITICAL ERROR: Order restoration failed!");
			hlogger.error("Expert Advisor cannot start safely with corrupted or inaccessible order data.");
			hlogger.error("Please check the JSON files in the Live/ directory or delete them to start fresh.");
			return INIT_FAILED;
		}

		if (total_restored > 0) {
			hlogger.info("Successfully restored " + IntegerToString(total_restored) + " orders from JSON files");
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

	for (int i = 0; i < ArraySize(strategies); i++)
		strategies[i].onDeinit();

	for (int i = 0; i < ArraySize(orders); i++)
		orders[i].onDeinit();

	for (int i = 0; i < ArraySize(orders_queue); i++)
		orders_queue[i].onDeinit();

	for (int i = 0; i < ArraySize(closed_orders); i++)
		closed_orders[i].onDeinit();

	ArrayResize(orders, 0);
	ArrayFree(orders);
	ArrayResize(orders_queue, 0);
	ArrayFree(orders_queue);
	ArrayResize(closed_orders, 0);
	ArrayFree(closed_orders);

	ArrayResize(strategies, 0);
	ArrayFree(strategies);

	if (CheckPointer(order_history_reporter) != POINTER_INVALID)
		delete order_history_reporter;

	if (CheckPointer(order_persistence) != POINTER_INVALID)
		delete order_persistence;

	for (int i = 0; i < ArraySize(all_strategies); i++)
		if (CheckPointer(all_strategies[i]) != POINTER_INVALID)
			delete all_strategies[i];
}

void OnTimer() {
	if (dtime.Now().hour < 1)
		return;

	// Start of week (Monday) - executed FIRST
	if (dtime.Now().day_of_week == 1 && last_start_week_yday != dtime.Now().day_of_year) {
		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].onStartWeek();

		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].onStartWeek();

		last_start_week_yday = dtime.Now().day_of_year;
	}

	// End of week (Friday 23:00 or later) - executed BEFORE daily/hourly triggers
	if (dtime.Now().day_of_week == 5 && dtime.Now().hour >= 23 && last_end_week_yday != dtime.Now().day_of_year) {
		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].onEndWeek();

		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].onEndWeek();

		last_end_week_yday = dtime.Now().day_of_year;
	}

	// Start of new day
	if (dtime.Now().day_of_year != last_checked_day) {
		last_checked_day = dtime.Now().day_of_year;
		deleteOldOrders();

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].onStartDay();

		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].onStartDay();
	}

	// Start of new hour
	if (dtime.Now().hour != last_checked_hour) {
		last_checked_hour = dtime.Now().hour;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].onStartHour();

		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].onStartHour();
	}

	// Start of new month
	if (dtime.Now().mon != last_checked_month) {
		last_checked_month = dtime.Now().mon;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].onStartMonth();

		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].onStartMonth();
	}

	// Start of new minute
	static int last_checked_minute = -1;
	if (dtime.Now().min != last_checked_minute) {
		last_checked_minute = dtime.Now().min;

		for (int i = 0; i < ArraySize(assets); i++)
			assets[i].onStartMinute();

		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].onStartMinute();
	}

	// Per-tick processing
	for (int i = 0; i < ArraySize(assets); i++)
		assets[i].onTick();

	for (int i = 0; i < ArraySize(strategies); i++)
		strategies[i].onTick();

	for (int i = 0; i < ArraySize(orders); i++) {
		if (!orders[i].is_initialized)
			orders[i].onInit();

		ENUM_ORDER_STATUSES previous_status = orders[i].status;

		if (orders[i].status == ORDER_STATUS_PENDING)
			orders[i].CheckToOpen();

		if (previous_status == ORDER_STATUS_PENDING && orders[i].status == ORDER_STATUS_CANCELLED) {
			for (int j = 0; j < ArraySize(strategies); j++) {
				if (orders[i].source == strategies[j].prefix) {
					strategies[j].onOpenOrder(orders[i]);
					break;
				}
			}
		}
	}

	for (int i = 0; i < ArraySize(orders_queue); i++) {
		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = orders_queue[i];
		hlogger.debug("Recovery order transferred from queue to main orders: " + orders_queue[i].Id());
	}

	if (ArraySize(orders_queue) > 0)
		ArrayResize(orders_queue, 0);
}

void OnTradeTransaction(
	const MqlTradeTransaction &transaction,
	const MqlTradeRequest &request,
	const MqlTradeResult &result
	) {
	if (transaction.type == TRADE_TRANSACTION_HISTORY_ADD) {
		if (HistoryOrderSelect(transaction.order)) {
			ulong order_state = HistoryOrderGetInteger(transaction.order, ORDER_STATE);

			if (order_state == 2) {
				ulong order_id = transaction.order;

				for (int i = 0; i < ArraySize(orders); i++) {
					if (orders[i].order_id == order_id && (orders[i].status == ORDER_STATUS_CLOSING || orders[i].status == ORDER_STATUS_PENDING)) {
						MqlDateTime cancel_time = dtime.Now();
						orders[i].OnClose(cancel_time, 0.0, 0.0, DEAL_REASON_EXPERT);

						for (int j = 0; j < ArraySize(strategies); j++) {
							if (orders[i].source == strategies[j].prefix) {
								strategies[j].onCloseOrder(orders[i], DEAL_REASON_EXPERT);
								break;
							}
						}

						hlogger.debug("OnTradeTransaction: Order cancelled with order_id=" + IntegerToString(order_id));
						break;
					}
				}
			}
		}
	}

	if (HistoryDealSelect(transaction.deal)) {
		ulong magic = HistoryDealGetInteger(transaction.deal, DEAL_MAGIC);
		string symbol = HistoryDealGetString(transaction.deal, DEAL_SYMBOL);

		bool valid_magic = false;
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (magic == strategies[i].strategy_magic_number) {
				valid_magic = true;
				break;
			}
		}

		if (!valid_magic && magic != 0)
			return;

		if (transaction.type == TRADE_TRANSACTION_DEAL_ADD) {
			int entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
			int reason = (int)HistoryDealGetInteger(transaction.deal, DEAL_REASON);
			string comment = HistoryDealGetString(transaction.deal, DEAL_COMMENT);
			ulong position_id = transaction.position;
			ulong order_id = transaction.order;
			ulong deal_id = transaction.deal;

			hlogger.debug("OnTradeTransaction: comment=" + comment + ", position_id=" + IntegerToString(position_id) + ", order_id=" + IntegerToString(order_id) + ", deal_id=" + IntegerToString(deal_id));
			hlogger.debug("OnTradeTransaction: entry=" + IntegerToString(entry) + ", reason=" + IntegerToString(reason));

			if (entry == DEAL_ENTRY_OUT) {
				MqlDateTime deal_time = dtime.Now();
				double deal_price = HistoryDealGetDouble(deal_id, DEAL_PRICE);
				double deal_profit = HistoryDealGetDouble(deal_id, DEAL_PROFIT);
				double deal_commission = HistoryDealGetDouble(deal_id, DEAL_COMMISSION);
				double deal_swap = HistoryDealGetDouble(deal_id, DEAL_SWAP);
				double net_profit = deal_profit + (deal_commission * 2) + deal_swap;
				ENUM_DEAL_REASON deal_reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_id, DEAL_REASON);
				int size = ArraySize(orders);
				int idx = -1;

				hlogger.debug("OnTradeTransaction: Closing order with deal_id=" + IntegerToString(deal_id) + ", position_id=" + IntegerToString(position_id));

				for (int i = 0; i < size; i++) {
					if (orders[i].position_id == position_id) {
						idx = i;
						break;
					}
				}

				if (idx == -1) {
					hlogger.warning("OnTradeTransaction: Order not found with position_id=" + IntegerToString(position_id));
					return;
				}

				orders[idx].OnClose(
					deal_time,
					deal_price,
					net_profit,
					deal_reason
					);

				for (int i = 0; i < ArraySize(strategies); i++) {
					if (orders[idx].source == strategies[i].prefix) {
						strategies[i].onCloseOrder(orders[idx], deal_reason);
						break;
					}
				}

				hlogger.info("OnTradeTransaction: Order closed with position_id=" + IntegerToString(position_id) + ", profit=" + DoubleToString(net_profit, 2));
			} else if (entry == DEAL_ENTRY_IN) {
				int size = ArraySize(orders);
				int idx = -1;

				for (int i = 0; i < size; i++) {
					if (orders[i].order_id == order_id) {
						idx = i;
						break;
					}
				}

				if (idx == -1) {
					hlogger.warning("OnTradeTransaction: Order not found with order_id=" + IntegerToString(order_id));
					return;
				}

				orders[idx].OnOpen(result);

				for (int j = 0; j < ArraySize(strategies); j++) {
					if (orders[idx].source == strategies[j].prefix) {
						strategies[j].onOpenOrder(orders[idx]);
						break;
					}
				}

				hlogger.debug("OnTradeTransaction: Updated order with deal_id=" + IntegerToString(deal_id) + ", position_id=" + IntegerToString(position_id));
			}
		}
	}
}

double OnTester() {
	double quality = 1.0;

	for (int i = 0; i < ArraySize(strategies); i++) {
		strategies[i].statistics.onForceEnd();
		double strategy_quality = strategies[i].statistics.getQuality().quality;

		if (strategy_quality == 0)
			quality = 0;
		else
			quality = MathPow(quality * strategy_quality, 1.0 / 2.0);
	}

	if (CheckPointer(order_history_reporter) != POINTER_INVALID) {
		order_history_reporter.PrintCurrentPath();
		order_history_reporter.ExportOrderHistoryToJsonFile();
		hlogger.info("Order history exported with " + IntegerToString(order_history_reporter.GetOrderCount()) + " orders");
	}

	return quality;
}

int OnTesterInit() {
	for (int i = 0; i < ArraySize(assets); i++)
		for (int j = 0; j < ArraySize(assets[i].asset_strategies); j++)
			assets[i].asset_strategies[j].onTesterInit();

	for (int i = 0; i < ArraySize(all_strategies); i++)
		all_strategies[i].onTesterInit();

	return INIT_SUCCEEDED;
}

void OnTesterPass() {
}

void OnTesterDeinit() {
}
