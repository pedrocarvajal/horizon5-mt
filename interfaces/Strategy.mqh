#ifndef __STRATEGY_MQH__
#define __STRATEGY_MQH__

#include "../enums/EOrderStatuses.mqh"
#include "../enums/ETradingModes.mqh"

#include "../structs/SOrderHistory.mqh"
#include "../structs/SStatisticsSnapshot.mqh"
#include "../structs/SQualityThresholds.mqh"

#include "../services/Logger/Logger.mqh"
#include "../services/DateTime/DateTime.mqh"
#include "../services/Order/Order.mqh"
#include "../services/Statistics/Statistics.mqh"
#include "../helpers/isMarketClosed.mqh"


class IStrategy {
public:
	string name;
	string symbol;
	string prefix;

	ulong strategy_magic_number;
	ENUM_TRADING_MODES trading_mode;

	Logger logger;
	Statistics *statistics;

private:
	double balance;

public:
	virtual int onInit() {
		if (!SymbolSelect(symbol, true)) {
			logger.error(StringFormat("Symbol '%s' does not exist or cannot be selected", symbol));
			return INIT_FAILED;
		}

		statistics = new Statistics(symbol, name, prefix, balance);
		logger.SetPrefix(name);

		return INIT_SUCCEEDED;
	};

	virtual void onDeinit() {
		delete statistics;
	};

	virtual int onTesterInit() {
		return INIT_SUCCEEDED;
	};

	virtual void onTick() {
	};

	virtual void onStartMinute() {
	};

	virtual void onStartHour() {
		statistics.onStartHour();
	};

	virtual void onStartDay() {
		statistics.onStartDay();
	};

	virtual void onStartWeek() {
		statistics.onStartWeek();
	};

	virtual void onStartMonth() {
		statistics.onStartMonth();
	};

	virtual void onEndWeek() {
	};

	virtual void onOpenOrder(Order &order) {
		statistics.onOpenOrder(order);
	};

	virtual void onCloseOrder(Order &order, ENUM_DEAL_REASON reason) {
		statistics.onCloseOrder(order, reason);
	};

	Order *openNewOrder(
		int layer,
		ENUM_ORDER_TYPE side,
		double open_at_price,
		double volume,
		bool is_market_order = false
		) {
		if (isMarketClosed(symbol)) {
			logger.warning("Order blocked: Market is closed");
			return NULL;
		}

		if (!validateTradingMode(side))
			return NULL;

		Order *order = new Order(strategy_magic_number, symbol);

		double current_price = (side == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

		order.status = ORDER_STATUS_PENDING;
		order.source = prefix;
		order.source_custom_id = "";
		order.side = side;
		order.layer = layer;
		order.volume = volume;
		order.signal_price = current_price;
		order.open_at_price = open_at_price;
		order.signal_at = dtime.Now();

		order.is_market_order = is_market_order;

		order.Id();

		return order;
	}

	double getLotSize() {
		// double portfolio_strategies_count = ArraySize(strategies);
		double portfolio_strategies_count = 1;
		double allocation = 1.0 / portfolio_strategies_count;
		double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
		double lot = 0;

		logger.info("Getting lot size");
		logger.info("Using equal weight allocation");

		if (equity_at_risk_mode == EQUITY_AT_RISK_LOT) {
			double equity_at_risk_to_use = equity_at_risk;
			double lot_multiplier = getLotMultiplier();

			if (equity_at_risk_multiply_by_strategy)
				equity_at_risk_to_use = equity_at_risk * portfolio_strategies_count;

			if (equity_at_risk_compounded) {
				logger.info("Compounded is enabled");
				lot = ((account_equity * equity_at_risk_to_use) / equity_at_risk_based_on) * allocation * lot_multiplier;
			} else {
				logger.info("Compounded is disabled");
				lot = allocation * equity_at_risk_to_use * lot_multiplier;
			}

			logger.info(StringFormat("Lot size: %.2f (multiplier: %.2f)", lot, lot_multiplier));
		}

		return lot;
	}

	virtual void setBalance(double allocated_balance) {
		balance = allocated_balance;
	}

	virtual void setQualityThresholds(SQualityThresholds &thresholds) {
		statistics.setQualityThresholds(thresholds);
	}

	void getOpenOrders(Order& result_orders[], ENUM_ORDER_TYPE side = -1, ENUM_ORDER_STATUSES status = -1) {
		filterOrders(orders, result_orders, side, status, ORDER_STATUS_OPEN, ORDER_STATUS_PENDING);
	}

	void getClosedOrders(Order& result_orders[], ENUM_ORDER_TYPE side = -1, ENUM_ORDER_STATUSES status = -1) {
		filterOrders(closed_orders, result_orders, side, status, ORDER_STATUS_CLOSED, ORDER_STATUS_CANCELLED);
	}

private:
	double getPointValue(string target_symbol) {
		double tick_value = SymbolInfoDouble(target_symbol, SYMBOL_TRADE_TICK_VALUE);
		double tick_size = SymbolInfoDouble(target_symbol, SYMBOL_TRADE_TICK_SIZE);
		double point_size = SymbolInfoDouble(target_symbol, SYMBOL_POINT);

		if (tick_size <= 0)
			return 0.0;

		return tick_value * (point_size / tick_size);
	}

	double getLotMultiplier() {
		string reference_symbol = "EURUSD";

		logger.debug(StringFormat("[getLotMultiplier] Starting calculation for symbol: %s, reference: %s", symbol, reference_symbol));

		double reference_point_value = getPointValue(reference_symbol);
		double current_point_value = getPointValue(symbol);

		logger.debug(StringFormat("[getLotMultiplier] Reference %s Point Value: $%.2f", reference_symbol, reference_point_value));
		logger.debug(StringFormat("[getLotMultiplier] Current %s Point Value: $%.2f", symbol, current_point_value));

		if (reference_point_value <= 0 || current_point_value <= 0) {
			logger.warning(StringFormat("[getLotMultiplier] Invalid point values for %s or %s, using default multiplier 1.0", symbol, reference_symbol));
			return 1.0;
		}

		double multiplier = reference_point_value / current_point_value;

		logger.debug(StringFormat("[getLotMultiplier] Final calculation: %.5f / %.5f = %.5f", reference_point_value, current_point_value, multiplier));
		logger.debug(StringFormat("[getLotMultiplier] Symbol: %s, Multiplier: %.3f", symbol, multiplier));

		return multiplier;
	}

	bool validateTradingMode(ENUM_ORDER_TYPE side) {
		if (trading_mode == TRADING_MODE_BUY_ONLY && side == ORDER_TYPE_SELL) {
			logger.warning("Order blocked: Trading mode is BUY_ONLY, cannot open SELL order");
			return false;
		}

		if (trading_mode == TRADING_MODE_SELL_ONLY && side == ORDER_TYPE_BUY) {
			logger.warning("Order blocked: Trading mode is SELL_ONLY, cannot open BUY order");
			return false;
		}

		return true;
	}

	void filterOrders(Order& source_orders[], Order& result_orders[], ENUM_ORDER_TYPE side, ENUM_ORDER_STATUSES status, ENUM_ORDER_STATUSES default_status1, ENUM_ORDER_STATUSES default_status2 = -1) {
		ArrayResize(result_orders, 0);

		for (int i = 0; i < ArraySize(source_orders); i++) {
			if (source_orders[i].source != prefix)
				continue;

			bool side_match = (side == -1) || (source_orders[i].side == side);
			bool status_match = false;

			if (status == -1) {
				status_match = (source_orders[i].status == default_status1);
				if (default_status2 != -1)
					status_match = status_match || (source_orders[i].status == default_status2);
			} else {
				status_match = (source_orders[i].status == status);
			}

			if (side_match && status_match) {
				ArrayResize(result_orders, ArraySize(result_orders) + 1);
				result_orders[ArraySize(result_orders) - 1] = source_orders[i];
			}
		}
	}
};

#endif
