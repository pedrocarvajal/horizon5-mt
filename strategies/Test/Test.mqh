#ifndef __STRATEGY_TEST_MQH__
#define __STRATEGY_TEST_MQH__

#include "../../interfaces/Strategy.mqh"
#include "../../structs/SQualityThresholds.mqh"

input group "Test Strategy Settings";
input double test_take_profit_points = 500; // [TEST] > Take Profit (points)
input double test_stop_loss_points = 250; // [TEST] > Stop Loss (points)
input ENUM_ORDER_TYPE test_order_side = ORDER_TYPE_BUY; // [TEST] > Order Side

class Test:
public IStrategy {
public:
	Test(string strategy_symbol) {
		symbol = strategy_symbol;
		name = "Test";
		prefix = "TST";
	}

private:
	int onInit() {
		IStrategy::onInit();

		setupQualityThresholds();

		return INIT_SUCCEEDED;
	}

	void onStartDay() {
		IStrategy::onStartDay();

		openDailyOrder();
	}

	void openDailyOrder() {
		double lot_size = getLotSize();

		if (lot_size <= 0) {
			logger.warning("Invalid lot size, skipping order");
			return;
		}

		double current_price = (test_order_side == ORDER_TYPE_BUY)
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);

		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

		Order *order = openNewOrder(
			1,
			test_order_side,
			current_price,
			lot_size,
			true
		);

		if (order == NULL) {
			logger.error("Failed to create order");
			return;
		}

		if (test_order_side == ORDER_TYPE_BUY) {
			order.main_take_profit_at_price = current_price + (test_take_profit_points * point);
			order.main_stop_loss_at_price = current_price - (test_stop_loss_points * point);
		} else {
			order.main_take_profit_at_price = current_price - (test_take_profit_points * point);
			order.main_stop_loss_at_price = current_price + (test_stop_loss_points * point);
		}

		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = order;

		logger.info(StringFormat(
			"Daily order created: %s %.2f lots @ %.5f | TP: %.5f | SL: %.5f",
			(test_order_side == ORDER_TYPE_BUY) ? "BUY" : "SELL",
			lot_size,
			current_price,
			order.main_take_profit_at_price,
			order.main_stop_loss_at_price
		));
	}

	void setupQualityThresholds() {
		SQualityThresholds thresholds;

		thresholds.optimization_formula = OPTIMIZATION_BY_PERFORMANCE;

		thresholds.expected_total_return_pct_by_month = 0.01;
		thresholds.expected_max_drawdown_pct = 0.01;
		thresholds.expected_win_rate = 1;
		thresholds.expected_recovery_factor = 3;
		thresholds.expected_risk_reward_ratio = 1;
		thresholds.expected_r_squared = 0.95;
		thresholds.expected_trades = 28;
		thresholds.expected_layer_distribution = 1;

		thresholds.min_total_return_pct = 0.0;
		thresholds.max_max_drawdown_pct = 0.30;
		thresholds.min_win_rate = 0;
		thresholds.min_risk_reward_ratio = 0;
		thresholds.min_recovery_factor = 1;
		thresholds.min_r_squared = 0.0;
		thresholds.min_trades = 5;
		thresholds.min_layer_distribution = 0.30;

		setQualityThresholds(thresholds);
	}
};

#endif
