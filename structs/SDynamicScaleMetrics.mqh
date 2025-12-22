#ifndef __SDYNAMIC_SCALE_METRICS_MQH__
#define __SDYNAMIC_SCALE_METRICS_MQH__

struct SDynamicScaleMetrics {
	double expected_value;
	double volatility;
	double win_rate;
	double drawdown;
	double kelly_criterion;
};

#endif
