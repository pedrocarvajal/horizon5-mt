#ifndef __SQUALITY_THRESHOLDS_MQH__
#define __SQUALITY_THRESHOLDS_MQH__

#include "../enums/EOptimizationResultFormula.mqh"

struct SQualityThresholds {
	ENUM_OPTIMIZATION_RESULT_FORMULA optimization_formula;

	double expected_total_return_pct_by_month;
	double expected_max_drawdown_pct;
	double expected_win_rate;
	double expected_recovery_factor;
	double expected_risk_reward_ratio;
	double expected_r_squared;
	int expected_trades;
	double expected_layer_distribution;

	double min_total_return_pct;
	double max_max_drawdown_pct;
	double min_win_rate;
	double min_risk_reward_ratio;
	double min_recovery_factor;
	double min_r_squared;
	int min_trades;
	double min_layer_distribution;
};

#endif
