#ifndef __S_QUALITY_THRESHOLDS_MQH__
#define __S_QUALITY_THRESHOLDS_MQH__

#include "../enums/EOptimizationResultFormula.mqh"

struct SQualityThresholds {
	ENUM_OPTIMIZATION_RESULT_FORMULA optimizationFormula;

	double expectedTotalReturnPctByMonth;
	double expectedMaxDrawdownPct;
	double expectedWinRate;
	double expectedRecoveryFactor;
	double expectedRiskRewardRatio;
	double expectedRSquared;
	int expectedTrades;

	double minTotalReturnPct;
	double maxMaxDrawdownPct;
	double minWinRate;
	double minRiskRewardRatio;
	double minRecoveryFactor;
	double minRSquared;
	int minTrades;
};

#endif
