#ifndef __IN_SWING_POINTS_MQH__
#define __IN_SWING_POINTS_MQH__

struct SSwingPoint {
	double price;
	bool isHigh;
	int barIndex;
};

int DetectSwingPoints(
	string symbolName,
	ENUM_TIMEFRAMES timeframe,
	int lookback,
	int swingPeriod,
	int signalBarShift,
	SSwingPoint &points[]
) {
	int totalBars = lookback + signalBarShift + swingPeriod;
	double high[];
	double low[];

	ArraySetAsSeries(high, true);
	ArraySetAsSeries(low, true);

	if (CopyHigh(symbolName, timeframe, signalBarShift, totalBars, high) < totalBars) {
		return 0;
	}

	if (CopyLow(symbolName, timeframe, signalBarShift, totalBars, low) < totalBars) {
		return 0;
	}

	int count = 0;
	int maxCandidates = MathMax(0, totalBars - 2 * swingPeriod);
	ArrayResize(points, maxCandidates * 2);

	int firstCandidate = swingPeriod;
	int lastCandidate = totalBars - swingPeriod - 1;

	for (int i = firstCandidate; i <= lastCandidate; i++) {
		if (i < 1) {
			continue;
		}

		bool isSwingHigh = true;
		bool isSwingLow = true;

		for (int j = 1; j <= swingPeriod; j++) {
			if (high[i] <= high[i - j] || high[i] <= high[i + j]) {
				isSwingHigh = false;
			}

			if (low[i] >= low[i - j] || low[i] >= low[i + j]) {
				isSwingLow = false;
			}

			if (!isSwingHigh && !isSwingLow) {
				break;
			}
		}

		if (isSwingHigh) {
			points[count].price = high[i];
			points[count].isHigh = true;
			points[count].barIndex = i;
			count++;
		}

		if (isSwingLow) {
			points[count].price = low[i];
			points[count].isHigh = false;
			points[count].barIndex = i;
			count++;
		}
	}

	ArrayResize(points, count);

	return count;
}

#endif
