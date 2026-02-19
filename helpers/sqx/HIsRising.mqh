#ifndef __SQX_IS_RISING_MQH__
#define __SQX_IS_RISING_MQH__

bool IsRising(double &values[], int bars, bool allowSameValues) {
	if (ArraySize(values) < bars) {
		return false;
	}

	bool atLeastOnce = false;
	double lastValue = values[0];

	for (int i = 1; i < bars; i++) {
		if (values[i] < lastValue) {
			return false;
		}

		if (!allowSameValues && MathAbs(values[i] - lastValue) < 0.00001) {
			return false;
		}

		if (values[i] > lastValue) {
			atLeastOnce = true;
		}

		lastValue = values[i];
	}

	return atLeastOnce;
}

bool IsFalling(double &values[], int bars, bool allowSameValues) {
	if (ArraySize(values) < bars) {
		return false;
	}

	bool atLeastOnce = false;
	double lastValue = values[0];

	for (int i = 1; i < bars; i++) {
		if (values[i] > lastValue) {
			return false;
		}

		if (!allowSameValues && MathAbs(values[i] - lastValue) < 0.00001) {
			return false;
		}

		if (values[i] < lastValue) {
			atLeastOnce = true;
		}

		lastValue = values[i];
	}

	return atLeastOnce;
}

#endif
