#ifndef __H_CALCULATE_QUALITY_MQH__
#define __H_CALCULATE_QUALITY_MQH__

#include "../../../structs/SSQualityResult.mqh"

#include "../../../constants/COStatistics.mqh"

SSQualityResult CalculateQuality(double totalPerformance, double drawdownMaxInDollars) {
	SSQualityResult result;

	if (totalPerformance <= 0) {
		result.quality = 0;
		result.reason = "Total performance is zero or negative";
		return result;
	}

	if (drawdownMaxInDollars <= DRAWDOWN_EPSILON) {
		result.quality = 0;
		result.reason = "Maximum drawdown is zero";
		return result;
	}

	result.quality = totalPerformance / drawdownMaxInDollars;
	result.reason = NULL;

	return result;
}

#endif
