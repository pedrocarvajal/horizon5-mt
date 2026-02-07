#ifndef __SQX_GET_PRICE_VALUE_MQH__
#define __SQX_GET_PRICE_VALUE_MQH__

double GetPriceValue(string symbolName, ENUM_TIMEFRAMES timeframe, int priceType, int shift) {
	double prices[];
	ArraySetAsSeries(prices, true);

	int copied = 0;

	if (priceType == PRICE_OPEN)
		copied = CopyOpen(symbolName, timeframe, shift, 1, prices);
	else if (priceType == PRICE_HIGH)
		copied = CopyHigh(symbolName, timeframe, shift, 1, prices);
	else if (priceType == PRICE_LOW)
		copied = CopyLow(symbolName, timeframe, shift, 1, prices);
	else if (priceType == PRICE_CLOSE)
		copied = CopyClose(symbolName, timeframe, shift, 1, prices);

	if (copied > 0)
		return prices[0];

	return 0.0;
}

bool GetPriceValues(string symbolName, ENUM_TIMEFRAMES timeframe, int priceType, int shift, int count, double &prices[]) {
	int copied = 0;

	if (priceType == PRICE_OPEN)
		copied = CopyOpen(symbolName, timeframe, shift, count, prices);
	else if (priceType == PRICE_HIGH)
		copied = CopyHigh(symbolName, timeframe, shift, count, prices);
	else if (priceType == PRICE_LOW)
		copied = CopyLow(symbolName, timeframe, shift, count, prices);
	else if (priceType == PRICE_CLOSE)
		copied = CopyClose(symbolName, timeframe, shift, count, prices);

	return copied == count;
}

#endif
