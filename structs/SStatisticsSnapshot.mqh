#ifndef __SSTATISTICS_SNAPSHOT_MQH__
#define __SSTATISTICS_SNAPSHOT_MQH__

struct SStatisticsSnapshot {
	datetime timestamp;
	string id;

	double nav[];
	double performance[];
	double nav_peak;
	double drawdown_max_in_dollars;
	double drawdown_max_in_percentage;
	int winning_orders;
	double winning_orders_performance;
	int losing_orders;
	double losing_orders_performance;
	double max_loss;

	double r_squared;
	double sharpe_ratio;
	double risk_reward_ratio;
	double win_rate;
	double recovery_factor;

	double quality;
	string quality_reason;

	double max_exposure_in_lots;
	double max_exposure_in_percentage;

	// For custom formula: SRSniper
	int closed_orders_on_layers_0;
	int closed_orders_on_layers_1;
	int closed_orders_on_layers_2;
	int closed_orders_on_layers_3;
	int closed_orders_on_layers_4;
	int closed_orders_on_layers_5;

	SOrderHistory orders[];
};

#endif
