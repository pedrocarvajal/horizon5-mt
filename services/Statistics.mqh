#ifndef __STATISTICS_MQH__
#define __STATISTICS_MQH__

class Statistics {
public:
	string class_name;
	SStatisticsSnapshot snapshots[];
	Logger logger;

private:
	string id;
	string strategy_name;
	string strategy_prefix;
	string symbol;
	datetime start_time;

	SQualityThresholds quality_thresholds;

	double nav[];
	double performance[];
	double returns[];

	double nav_peak;
	double drawdown_max_in_dollars;
	double drawdown_max_in_percentage;

	int winning_orders;
	double winning_orders_performance;

	int losing_orders;
	double losing_orders_performance;
	double max_loss;

	double risk_reward_ratio;
	double win_rate;
	double recovery_factor;

	double nav_yesterday;
	double daily_performance;
	double daily_performance_in_percentage;

	int months_in_backtest;
	SOrderHistory orders[];
	Order last_closed_orders[];
	Order open_orders[];

	double max_exposure_in_lots;
	double max_exposure_in_percentage;

	bool stop_out_detected;
	double initial_balance;
	double final_equity;
	double stop_out_threshold;

	int closed_orders_on_layers_0;
	int closed_orders_on_layers_1;
	int closed_orders_on_layers_2;
	int closed_orders_on_layers_3;
	int closed_orders_on_layers_4;
	int closed_orders_on_layers_5;

	double chain_of_losses_amount;

public:
	Statistics(string _symbol, string name, string prefix, double allocated_balance) {
		symbol = _symbol;
		start_time = StructToTime(dtime.Now());
		id = TimeToString(StructToTime(dtime.Now()), TIME_DATE | TIME_SECONDS);
		strategy_name = name;
		strategy_prefix = prefix;
		class_name = "Statistics: " + name;
		logger.SetPrefix("Statistics[" + name + "]");

		ArrayResize(nav, 1);
		nav[0] = allocated_balance;
		nav_peak = nav[0];
		nav_yesterday = allocated_balance;
		daily_performance = 0.0;
		daily_performance_in_percentage = 0.0;

		ArrayResize(performance, 1);
		performance[0] = 0.0;

		ArrayResize(returns, 0);
		ArrayResize(open_orders, 0);

		max_exposure_in_lots = 0.0;
		max_exposure_in_percentage = 0.0;

		stop_out_detected = false;
		initial_balance = allocated_balance;
		final_equity = allocated_balance;
		stop_out_threshold = 0.20;

		closed_orders_on_layers_0 = 0;
		closed_orders_on_layers_1 = 0;
		closed_orders_on_layers_2 = 0;
		closed_orders_on_layers_3 = 0;
		closed_orders_on_layers_4 = 0;
		closed_orders_on_layers_5 = 0;

		chain_of_losses_amount = 0.0;

		drawdown_max_in_dollars = 0.0;
		drawdown_max_in_percentage = 0.0;
		max_loss = 0.0;
	}

	void setQualityThresholds(SQualityThresholds &thresholds) {
		quality_thresholds = thresholds;
	}

	double getCurrentPerformance() {
		return (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0.0;
	}

	double getDailyPerformance() {
		return daily_performance;
	}

	double getDailyPerformanceInPercentage() {
		return daily_performance_in_percentage;
	}

	void getReturns(double &response[]) {
		ArrayResize(response, ArraySize(returns));

		for (int i = 0; i < ArraySize(returns); i++)
			response[i] = returns[i];
	}

	double getMaxExposureInLots() {
		return max_exposure_in_lots;
	}

	double getMaxExposureInPercentage() {
		return max_exposure_in_percentage;
	}

	void onOpenOrder(Order &order) {
		if (order.status == ORDER_STATUS_CANCELLED)
			return;

		ArrayResize(open_orders, ArraySize(open_orders) + 1);
		open_orders[ArraySize(open_orders) - 1] = order;

		updateExposureFromOpenOrders();
	}

	void onCloseOrder(Order &order, ENUM_DEAL_REASON reason) {
		removeFromOpenOrders(order);

		ArrayResize(last_closed_orders, ArraySize(last_closed_orders) + 1);
		last_closed_orders[ArraySize(last_closed_orders) - 1] = order;

		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = order.snapshot;

		updateExposureFromOpenOrders();
		updateRecoveryOrdersCounters(order);
	}

	void onStartHour() {
		ArrayResize(performance, ArraySize(performance) + 1);
		ArrayResize(nav, ArraySize(nav) + 1);

		double prev_nav = (ArraySize(nav) > 1) ? nav[ArraySize(nav) - 2] : nav[0];
		double prev_performance = (ArraySize(performance) > 1) ? performance[ArraySize(performance) - 2] : 0;

		performance[ArraySize(performance) - 1] = prev_performance;
		nav[ArraySize(nav) - 1] = prev_nav;

		processPendingOrders();
	}

	void onStartDay() {
		double current_nav = (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : nav[0];
		daily_performance = current_nav - nav_yesterday;
		daily_performance_in_percentage = (nav_yesterday > 0) ? daily_performance / nav_yesterday : 0.0;
		nav_yesterday = current_nav;

		ArrayResize(returns, ArraySize(returns) + 1);
		returns[ArraySize(returns) - 1] = getDailyPerformance();
	}

	void onStartWeek() {
	}

	void onStartMonth(bool save_snapshot = false) {
		months_in_backtest++;
		processPendingOrders();

		if (save_snapshot)
			snapshot();
	}

	void onForceEnd() {
		detectStopOut();
		processPendingOrders();
		snapshot();
	}

	void updateChainOfLosses(double amount, bool reset = false) {
		if (reset) {
			chain_of_losses_amount = 0.0;
			logger.debug("Chain of losses reset");
			return;
		}

		if (amount < 0)
			chain_of_losses_amount += MathAbs(amount);
		else if (amount > 0)
			chain_of_losses_amount = MathMax(0.0, chain_of_losses_amount - amount);

		logger.debug(StringFormat("Chain of losses updated, amount to recover: %.2f", chain_of_losses_amount));
	}

	double getR2(double &points[]) {
		if (ArraySize(points) < 3)
			return 0;

		double x_values[];
		double y_values[];

		ArrayResize(x_values, ArraySize(points));
		ArrayResize(y_values, ArraySize(points));

		for (int i = 0; i < ArraySize(points); i++) {
			x_values[i] = i;
			y_values[i] = points[i];
		}

		double n = ArraySize(points);
		double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;

		for (int i = 0; i < n; i++) {
			sum_x += x_values[i];
			sum_y += y_values[i];
			sum_xy += x_values[i] * y_values[i];
			sum_x2 += x_values[i] * x_values[i];
			sum_y2 += y_values[i] * y_values[i];
		}

		double variance_x = n * sum_x2 - sum_x * sum_x;
		double variance_y = n * sum_y2 - sum_y * sum_y;

		if (variance_x <= 0.0000001 || variance_y <= 0.0000001)
			return 0;

		double numerator = n * sum_xy - sum_x * sum_y;
		double denominator = MathSqrt(variance_x * variance_y);

		if (denominator <= 0.0000001)
			return 0;

		double correlation = numerator / denominator;
		return correlation * correlation;
	}

	double getChainOfLosses() {
		return chain_of_losses_amount;
	}

	double getPortfolioDrawdown() {
		return drawdown_max_in_dollars;
	}

	double getSharpeRatio(double &perf[]) {
		int n = ArraySize(perf);

		if (n < 3)
			return 0.0;

		double mean = 0.0, var = 0.0;
		int m = 0;

		for (int i = 1; i < n; i++) {
			double d = perf[i] - perf[i - 1];
			mean += d;
			m++;
		}

		if (m < 2)
			return 0.0;

		mean /= (double)m;

		for (int i = 1; i < n; i++) {
			double d = perf[i] - perf[i - 1];
			double e = d - mean;
			var += e * e;
		}

		var /= (double)(m - 1);
		double sd = (var > 0.0 ? MathSqrt(var) : 0.0);

		if (sd <= 1e-12)
			return 0.0;

		return mean / sd;
	}

	double getRecoveryFactor() {
		if (drawdown_max_in_dollars <= 0.0000001)
			return 0;

		double total_profit = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;
		return total_profit / drawdown_max_in_dollars;
	}

	double getSumOf(double &points[]) {
		double sum = 0;

		for (int i = 0; i < ArraySize(points); i++)
			sum += points[i];

		return sum;
	}

	SQualityResult getQuality() {
		SQualityResult result;

		double total_orders = ArraySize(orders);
		double total_trades = winning_orders + losing_orders;
		double snapshot_performance = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;
		double performance_in_percentage = snapshot_performance / nav[0];
		double current_recovery_factor = getRecoveryFactor();
		double current_r_squared = getR2(performance);
		double current_layer_distribution = calculateLayerDistributionQuality();

		double q_performance = calculateMetricQuality(
			performance_in_percentage,
			quality_thresholds.expected_total_return_pct_by_month * months_in_backtest,
			quality_thresholds.min_total_return_pct,
			true
			);

		double q_drawdown = calculateMetricQuality(
			drawdown_max_in_percentage,
			quality_thresholds.expected_max_drawdown_pct,
			quality_thresholds.max_max_drawdown_pct,
			false
			);

		double q_risk_reward = calculateMetricQuality(
			risk_reward_ratio,
			quality_thresholds.expected_risk_reward_ratio,
			quality_thresholds.min_risk_reward_ratio,
			true
			);

		double q_win_rate = calculateMetricQuality(
			win_rate,
			quality_thresholds.expected_win_rate,
			quality_thresholds.min_win_rate,
			true
			);

		double q_r_squared = calculateMetricQuality(
			current_r_squared,
			quality_thresholds.expected_r_squared,
			quality_thresholds.min_r_squared,
			true
			);

		double q_trades = calculateMetricQuality(
			total_trades,
			quality_thresholds.expected_trades,
			quality_thresholds.min_trades,
			true
			);

		double q_layer_distribution = calculateMetricQuality(
			current_layer_distribution,
			quality_thresholds.expected_layer_distribution,
			quality_thresholds.min_layer_distribution,
			true
			);

		double q_recovery_factor = calculateMetricQuality(
			current_recovery_factor,
			quality_thresholds.expected_recovery_factor,
			quality_thresholds.min_recovery_factor,
			true
			);

		logger.debug("Quality performance results:");
		logger.debug(StringFormat("Performance: %.4f", q_performance));
		logger.debug(StringFormat("Drawdown: %.4f", q_drawdown));
		logger.debug(StringFormat("Risk-reward: %.4f", q_risk_reward));
		logger.debug(StringFormat("Win rate: %.4f", q_win_rate));
		logger.debug(StringFormat("R-squared: %.4f", q_r_squared));
		logger.debug(StringFormat("Trades: %.4f", q_trades));
		logger.debug(StringFormat("Layer distribution: %.4f", q_layer_distribution));

		if (stop_out_detected) {
			result.quality = 0;
			result.reason = "Stop out detected.";
			logger.debug(result.reason);
			return result;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_PERFORMANCE) {
			if (q_performance == 0) {
				result.quality = 0;
				result.reason = "Performance below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_performance;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_DRAWDOWN) {
			if (q_drawdown == 0) {
				result.quality = 0;
				result.reason = "Drawdown below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_drawdown;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_RISK_REWARD) {
			if (q_risk_reward == 0) {
				result.quality = 0;
				result.reason = "Risk-reward ratio below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_risk_reward;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_WIN_RATE) {
			if (q_win_rate == 0) {
				result.quality = 0;
				result.reason = "Win rate below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_win_rate;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_R_SQUARED) {
			if (q_r_squared == 0) {
				result.quality = 0;
				result.reason = "R-squared below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_r_squared;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_TRADES) {
			if (q_trades == 0) {
				result.quality = 0;
				result.reason = "Number of trades below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_trades;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_LAYER_DISTRIBUTION) {
			if (q_layer_distribution == 0) {
				result.quality = 0;
				result.reason = "Layer distribution below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_layer_distribution;
			result.reason = NULL;
		}

		if (quality_thresholds.optimization_formula == OPTIMIZATION_BY_RECOVERY_FACTOR) {
			if (q_recovery_factor == 0) {
				result.quality = 0;
				result.reason = "Recovery factor below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = q_recovery_factor;
			result.reason = NULL;
		}

		return result;
	}

private:
	void calculateRiskRewardRatio() {
		double avg_win = (winning_orders > 0) ? winning_orders_performance / winning_orders : 0;
		risk_reward_ratio = (max_loss > 0) ? avg_win / max_loss : 0;
	}

	void reset() {
		start_time = StructToTime(dtime.Now());

		double last_nav = (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : nav[0];
		double last_performance = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;

		ArrayResize(orders, 0);
		ArrayResize(last_closed_orders, 0);
		ArrayResize(open_orders, 0);
		ArrayResize(performance, 1);
		ArrayResize(nav, 1);
		ArrayResize(returns, 0);

		nav[0] = last_nav;
		performance[0] = last_performance;

		nav_peak = last_nav;
		nav_yesterday = last_nav;
		daily_performance = 0.0;
		daily_performance_in_percentage = 0.0;
		drawdown_max_in_dollars = 0;
		drawdown_max_in_percentage = 0;

		winning_orders = 0;
		winning_orders_performance = 0;

		losing_orders = 0;
		losing_orders_performance = 0;
		max_loss = 0.0;

		risk_reward_ratio = 0;
		win_rate = 0;
		recovery_factor = 0;

		max_exposure_in_lots = 0.0;
		max_exposure_in_percentage = 0.0;

		stop_out_detected = false;
		final_equity = last_nav;
		months_in_backtest = 0;

		closed_orders_on_layers_0 = 0;
		closed_orders_on_layers_1 = 0;
		closed_orders_on_layers_2 = 0;
		closed_orders_on_layers_3 = 0;
		closed_orders_on_layers_4 = 0;
		closed_orders_on_layers_5 = 0;
	}

	void snapshot() {
		SQualityResult quality = getQuality();
		SStatisticsSnapshot snapshot_data;
		snapshot_data.timestamp = StructToTime(dtime.Now());
		snapshot_data.id = id;

		for (int i = 0; i < ArraySize(orders); i++) {
			ArrayResize(snapshot_data.orders, ArraySize(snapshot_data.orders) + 1);
			snapshot_data.orders[ArraySize(snapshot_data.orders) - 1] = orders[i];
		}

		for (int i = 0; i < ArraySize(nav); i++) {
			ArrayResize(snapshot_data.nav, ArraySize(snapshot_data.nav) + 1);
			snapshot_data.nav[ArraySize(snapshot_data.nav) - 1] = nav[i];
		}

		for (int i = 0; i < ArraySize(performance); i++) {
			ArrayResize(snapshot_data.performance, ArraySize(snapshot_data.performance) + 1);
			snapshot_data.performance[ArraySize(snapshot_data.performance) - 1] = performance[i];
		}

		snapshot_data.nav_peak = nav_peak;
		snapshot_data.drawdown_max_in_dollars = drawdown_max_in_dollars;
		snapshot_data.drawdown_max_in_percentage = drawdown_max_in_percentage;
		snapshot_data.winning_orders = winning_orders;
		snapshot_data.winning_orders_performance = winning_orders_performance;
		snapshot_data.losing_orders = losing_orders;
		snapshot_data.losing_orders_performance = losing_orders_performance;
		snapshot_data.max_loss = max_loss;

		snapshot_data.r_squared = getR2(performance);
		snapshot_data.sharpe_ratio = getSharpeRatio(performance);
		snapshot_data.risk_reward_ratio = risk_reward_ratio;
		snapshot_data.win_rate = win_rate;
		snapshot_data.recovery_factor = getRecoveryFactor();

		snapshot_data.quality = quality.quality;
		snapshot_data.quality_reason = quality.reason;

		snapshot_data.max_exposure_in_lots = max_exposure_in_lots;
		snapshot_data.max_exposure_in_percentage = max_exposure_in_percentage;

		snapshot_data.closed_orders_on_layers_0 = closed_orders_on_layers_0;
		snapshot_data.closed_orders_on_layers_1 = closed_orders_on_layers_1;
		snapshot_data.closed_orders_on_layers_2 = closed_orders_on_layers_2;
		snapshot_data.closed_orders_on_layers_3 = closed_orders_on_layers_3;
		snapshot_data.closed_orders_on_layers_4 = closed_orders_on_layers_4;
		snapshot_data.closed_orders_on_layers_5 = closed_orders_on_layers_5;

		logger.separator(StringFormat("Snapshot: %s", TimeToString(snapshot_data.timestamp)));
		logger.debug(StringFormat("Strategy name: %s", strategy_name));
		logger.debug(StringFormat("Strategy prefix: %s", strategy_prefix));
		logger.debug(StringFormat("Start time: %s", TimeToString(start_time)));
		logger.debug(StringFormat("Orders: %d", ArraySize(snapshot_data.orders)));
		logger.debug(StringFormat("Nav: %.2f", (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : 0.0));
		logger.debug(StringFormat("Performance: %.2f", (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0.0));
		logger.debug(StringFormat("Winning orders: %d", winning_orders));
		logger.debug(StringFormat("Losing orders: %d", losing_orders));
		logger.debug(StringFormat("Winning orders performance: %.2f", winning_orders_performance));
		logger.debug(StringFormat("Losing orders performance: %.2f", losing_orders_performance));
		logger.debug(StringFormat("Max loss: %.2f", max_loss));
		logger.debug(StringFormat("Drawdown max in dollars: %.2f", drawdown_max_in_dollars));
		logger.debug(StringFormat("Drawdown max in percentage: %.2f%%", drawdown_max_in_percentage * 100));
		logger.debug(StringFormat("Risk/Reward ratio: %.2f", risk_reward_ratio));
		logger.debug(StringFormat("Sharpe ratio: %.4f", snapshot_data.sharpe_ratio));
		logger.debug(StringFormat("Win rate: %.2f%%", win_rate * 100));
		logger.debug(StringFormat("Recovery factor: %.2f", snapshot_data.recovery_factor));
		logger.debug(StringFormat("Quality: %.4f", snapshot_data.quality));
		logger.debug(StringFormat("Quality reason: %s", snapshot_data.quality_reason));
		logger.debug(StringFormat("Max exposure in lots: %.4f", snapshot_data.max_exposure_in_lots));
		logger.debug(StringFormat("Max exposure in percentage: %.4f", snapshot_data.max_exposure_in_percentage));
		logger.debug(StringFormat("Closed orders on layers 0: %d", snapshot_data.closed_orders_on_layers_0));
		logger.debug(StringFormat("Closed orders on layers 1: %d", snapshot_data.closed_orders_on_layers_1));
		logger.debug(StringFormat("Closed orders on layers 2: %d", snapshot_data.closed_orders_on_layers_2));
		logger.debug(StringFormat("Closed orders on layers 3: %d", snapshot_data.closed_orders_on_layers_3));
		logger.debug(StringFormat("Closed orders on layers 4: %d", snapshot_data.closed_orders_on_layers_4));
		logger.debug(StringFormat("Closed orders on layers 5: %d", snapshot_data.closed_orders_on_layers_5));

		ArrayResize(snapshots, ArraySize(snapshots) + 1);
		snapshots[ArraySize(snapshots) - 1] = snapshot_data;
	}

	void updateRecoveryOrdersCounters(Order &order) {
		if (order.layer == 0)
			closed_orders_on_layers_0++;
		else if (order.layer == 1)
			closed_orders_on_layers_1++;
		else if (order.layer == 2)
			closed_orders_on_layers_2++;
		else if (order.layer == 3)
			closed_orders_on_layers_3++;
		else if (order.layer == 4)
			closed_orders_on_layers_4++;
		else if (order.layer == 5)
			closed_orders_on_layers_5++;
	}

	void processPendingOrders() {
		if (ArraySize(last_closed_orders) == 0)
			return;

		double prev_nav = (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : nav[0];
		double prev_performance = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;

		double next_nav = prev_nav;
		double next_performance = prev_performance;

		for (int i = 0; i < ArraySize(last_closed_orders); i++) {
			Order order = last_closed_orders[i];
			next_performance += order.profit_in_dollars;
			next_nav += order.profit_in_dollars;

			if (order.profit_in_dollars > 0) {
				winning_orders++;
				winning_orders_performance += order.profit_in_dollars;
			} else {
				losing_orders++;
				losing_orders_performance += order.profit_in_dollars;
				double current_loss = MathAbs(order.profit_in_dollars);

				if (current_loss > max_loss)
					max_loss = current_loss;
			}

			if (next_nav > nav_peak)
				nav_peak = next_nav;
		}

		double drawdown_in_dollars = nav_peak - next_nav;
		double avg_win = (winning_orders > 0) ? winning_orders_performance / winning_orders : 0;

		if (drawdown_in_dollars > drawdown_max_in_dollars) {
			drawdown_max_in_dollars = drawdown_in_dollars;
			if (nav_peak > 0)
				drawdown_max_in_percentage = drawdown_max_in_dollars / nav_peak;
			else
				drawdown_max_in_percentage = 0.0;
		}

		win_rate = (winning_orders + losing_orders > 0) ? (double)winning_orders / (winning_orders + losing_orders) : 0;
		risk_reward_ratio = (max_loss > 0) ? avg_win / max_loss : 0;

		if (ArraySize(performance) > 0) {
			performance[ArraySize(performance) - 1] = next_performance;
		} else {
			ArrayResize(performance, 1);
			performance[0] = next_performance;
		}

		if (ArraySize(nav) > 0) {
			nav[ArraySize(nav) - 1] = next_nav;
		} else {
			ArrayResize(nav, 1);
			nav[0] = next_nav;
		}

		ArrayResize(last_closed_orders, 0);
	}

	void removeFromOpenOrders(Order &closed_order) {
		for (int i = 0; i < ArraySize(open_orders); i++) {
			if (open_orders[i].Id() == closed_order.Id()) {
				for (int j = i; j < ArraySize(open_orders) - 1; j++)
					open_orders[j] = open_orders[j + 1];
				ArrayResize(open_orders, ArraySize(open_orders) - 1);
				break;
			}
		}
	}

	void updateExposureFromOpenOrders() {
		double current_exposure_lots = 0.0;

		for (int i = 0; i < ArraySize(open_orders); i++) {
			if (open_orders[i].status == ORDER_STATUS_OPEN) {
				if (open_orders[i].side == ORDER_TYPE_BUY)
					current_exposure_lots += open_orders[i].volume;
				else if (open_orders[i].side == ORDER_TYPE_SELL)
					current_exposure_lots -= open_orders[i].volume;
			}
		}

		if (MathAbs(current_exposure_lots) > MathAbs(max_exposure_in_lots))
			max_exposure_in_lots = current_exposure_lots;

		double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
		double symbol_price = SymbolInfoDouble(symbol, SYMBOL_BID);
		double current_exposure_percentage = 0.0;

		if (account_equity > 0)
			current_exposure_percentage = (current_exposure_lots * symbol_price) / account_equity;

		if (MathAbs(current_exposure_percentage) > MathAbs(max_exposure_in_percentage))
			max_exposure_in_percentage = current_exposure_percentage;
	}

	double calculateLayerDistributionQuality() {
		int total_orders = closed_orders_on_layers_0 +
				   closed_orders_on_layers_1 +
				   closed_orders_on_layers_2 +
				   closed_orders_on_layers_3 +
				   closed_orders_on_layers_4 +
				   closed_orders_on_layers_5;

		if (total_orders == 0)
			return 1.0;

		double weighted_score = (closed_orders_on_layers_0 * 1.0) +
					(closed_orders_on_layers_1 * 0.8) +
					(closed_orders_on_layers_2 * 0.6) +
					(closed_orders_on_layers_3 * 0.3) +
					(closed_orders_on_layers_4 * 0.1) +
					(closed_orders_on_layers_5 * 0.05);

		double quality = weighted_score / total_orders;

		return quality;
	}

	bool detectStopOut() {
		final_equity = AccountInfoDouble(ACCOUNT_EQUITY);
		double equity_percentage = final_equity / initial_balance;

		if (equity_percentage < stop_out_threshold) {
			stop_out_detected = true;
			logger.debug(StringFormat("Stop out detected: Equity %.2f (%.2f%% of initial balance)", final_equity, equity_percentage * 100));

			return true;
		}

		if (equity_percentage < 0.50) {
			stop_out_detected = true;
			logger.debug(StringFormat("Severe equity loss detected: %.2f%% remaining", equity_percentage * 100));

			return true;
		}

		return false;
	}

	double calculateMetricQuality(double current_value, double expected_value, double threshold_value, bool higher_is_better) {
		if (higher_is_better) {
			if (current_value < threshold_value)
				return 0;

			if (current_value >= expected_value)
				return 1;

			return (current_value - threshold_value) / (expected_value - threshold_value);
		} else {
			if (current_value > threshold_value)
				return 0;

			if (current_value <= expected_value)
				return 1;

			return (threshold_value - current_value) / (threshold_value - expected_value);
		}
	}
};

#endif
