#ifndef __IN_FAIR_VALUE_GAP_MQH__
#define __IN_FAIR_VALUE_GAP_MQH__

enum ENUM_FVG_TYPE {
	FVG_BULLISH,
	FVG_BEARISH
};

struct SFairValueGap {
	ENUM_FVG_TYPE type;
	double bottom;
	double top;
	int formationBarIndex;
	bool valid;
};

int DetectFairValueGaps(
	string symbolName,
	ENUM_TIMEFRAMES timeframe,
	int lookback,
	int signalBarShift,
	SFairValueGap &zones[]
) {
	int totalBars = lookback + signalBarShift + 3;

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
	ArrayResize(zones, totalBars);

	for (int i = 2; i < totalBars; i++) {
		double olderHigh = high[i];
		double olderLow = low[i];
		double newerHigh = high[i - 2];
		double newerLow = low[i - 2];

		if (olderHigh < newerLow) {
			zones[count].type = FVG_BULLISH;
			zones[count].bottom = olderHigh;
			zones[count].top = newerLow;
			zones[count].formationBarIndex = i - 2;
			zones[count].valid = true;
			count++;
		} else if (olderLow > newerHigh) {
			zones[count].type = FVG_BEARISH;
			zones[count].bottom = newerHigh;
			zones[count].top = olderLow;
			zones[count].formationBarIndex = i - 2;
			zones[count].valid = true;
			count++;
		}
	}

	ArrayResize(zones, count);

	return count;
}

void RebalanceFairValueGaps(
	string symbolName,
	ENUM_TIMEFRAMES timeframe,
	int signalBarShift,
	SFairValueGap &zones[]
) {
	int zoneCount = ArraySize(zones);

	if (zoneCount == 0) {
		return;
	}

	double high[];
	double low[];

	ArraySetAsSeries(high, true);
	ArraySetAsSeries(low, true);

	for (int zoneIndex = 0; zoneIndex < zoneCount; zoneIndex++) {
		if (!zones[zoneIndex].valid) {
			continue;
		}

		int startShift = signalBarShift + 1;
		int barsToCheck = zones[zoneIndex].formationBarIndex - startShift;

		if (barsToCheck <= 0) {
			continue;
		}

		if (CopyHigh(symbolName, timeframe, startShift, barsToCheck, high) < barsToCheck) {
			continue;
		}

		if (CopyLow(symbolName, timeframe, startShift, barsToCheck, low) < barsToCheck) {
			continue;
		}

		for (int barIndex = barsToCheck - 1; barIndex >= 0; barIndex--) {
			if (!zones[zoneIndex].valid) {
				break;
			}

			if (zones[zoneIndex].type == FVG_BEARISH) {
				if (high[barIndex] > zones[zoneIndex].bottom && high[barIndex] < zones[zoneIndex].top) {
					zones[zoneIndex].bottom = MathMax(zones[zoneIndex].bottom, high[barIndex]);
				}
			} else if (zones[zoneIndex].type == FVG_BULLISH) {
				if (low[barIndex] < zones[zoneIndex].top && low[barIndex] > zones[zoneIndex].bottom) {
					zones[zoneIndex].top = MathMin(zones[zoneIndex].top, low[barIndex]);
				}
			}

			if (zones[zoneIndex].bottom >= zones[zoneIndex].top) {
				zones[zoneIndex].valid = false;
			}
		}
	}
}

#endif
