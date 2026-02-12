#ifndef __SQX_MOMENTUM_MQH__
#define __SQX_MOMENTUM_MQH__

double Momentum(string symbolName, ENUM_TIMEFRAMES timeframe, int period, int shift) {
	double closes[];
	ArraySetAsSeries(closes, true);

	int copied = CopyClose(symbolName, timeframe, shift, period + 1, closes);

	if (copied < period + 1)
		return 0.0;

	return closes[0] - closes[period];
}

#endif
