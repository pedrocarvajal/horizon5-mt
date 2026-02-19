#ifndef __IN_HIGHEST_MQH__
#define __IN_HIGHEST_MQH__

double Highest(string symbolName, ENUM_TIMEFRAMES timeframe, int priceType,
	       int period, int shift) {
	double values[];

	int copied = 0;

	if (priceType == PRICE_OPEN) {
		copied = CopyOpen(symbolName, timeframe, shift, period, values);
	} else if (priceType == PRICE_HIGH) {
		copied = CopyHigh(symbolName, timeframe, shift, period, values);
	} else if (priceType == PRICE_LOW) {
		copied = CopyLow(symbolName, timeframe, shift, period, values);
	} else if (priceType == PRICE_CLOSE) {
		copied = CopyClose(symbolName, timeframe, shift, period, values);
	}

	if (copied < period) {
		return 0.0;
	}

	double maxValue = values[0];

	for (int i = 1; i < period; i++) {
		if (values[i] > maxValue) {
			maxValue = values[i];
		}
	}

	return maxValue;
}

double Lowest(string symbolName, ENUM_TIMEFRAMES timeframe, int priceType,
	      int period, int shift) {
	double values[];

	int copied = 0;

	if (priceType == PRICE_OPEN) {
		copied = CopyOpen(symbolName, timeframe, shift, period, values);
	} else if (priceType == PRICE_HIGH) {
		copied = CopyHigh(symbolName, timeframe, shift, period, values);
	} else if (priceType == PRICE_LOW) {
		copied = CopyLow(symbolName, timeframe, shift, period, values);
	} else if (priceType == PRICE_CLOSE) {
		copied = CopyClose(symbolName, timeframe, shift, period, values);
	}

	if (copied < period) {
		return 0.0;
	}

	double minValue = values[0];

	for (int i = 1; i < period; i++) {
		if (values[i] < minValue) {
			minValue = values[i];
		}
	}

	return minValue;
}

#endif
