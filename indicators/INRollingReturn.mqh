#ifndef __IN_ROLLING_RETURN_MQH__
#define __IN_ROLLING_RETURN_MQH__

double RollingReturn(string symbolName, ENUM_TIMEFRAMES timeframe, int period, int shift) {
	double closes[];
	ArraySetAsSeries(closes, true);

	int copied = CopyClose(symbolName, timeframe, shift, period + 1, closes);

	if (copied < period + 1)
		return 0.0;

	if (closes[period] == 0.0)
		return 0.0;

	return (closes[0] - closes[period]) / closes[period];
}

#endif
