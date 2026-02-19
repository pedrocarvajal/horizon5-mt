#ifndef __H_CALCULATE_METRIC_QUALITY_MQH__
#define __H_CALCULATE_METRIC_QUALITY_MQH__

double CalculateMetricQuality(double currentValue, double expectedValue,
			      double thresholdValue, bool higherIsBetter) {
	if (higherIsBetter) {
		if (currentValue < thresholdValue) {
			return 0;
		}

		if (currentValue >= expectedValue) {
			return 1;
		}

		return (currentValue - thresholdValue) /
		       (expectedValue - thresholdValue);
	} else {
		if (currentValue > thresholdValue) {
			return 0;
		}

		if (currentValue <= expectedValue) {
			return 1;
		}

		return (thresholdValue - currentValue) /
		       (thresholdValue - expectedValue);
	}
}

#endif
