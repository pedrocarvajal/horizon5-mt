#ifndef __IN_HIGHEST_MQH__
#define __IN_HIGHEST_MQH__

double Highest(
	string symbolName,
	ENUM_TIMEFRAMES timeframe,
	ENUM_APPLIED_PRICE priceType,
	int period,
	int shift
) {
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

	return values[ArrayMaximum(values, 0, period)];
}

double Lowest(
	string symbolName,
	ENUM_TIMEFRAMES timeframe,
	ENUM_APPLIED_PRICE priceType,
	int period,
	int shift
) {
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

	return values[ArrayMinimum(values, 0, period)];
}

#endif
