#ifndef __IN_VOLATILITY_MQH__
#define __IN_VOLATILITY_MQH__

double Volatility(string symbolName, ENUM_TIMEFRAMES timeframe, int period, int shift) {
	double closes[];
	ArraySetAsSeries(closes, true);

	int copied = CopyClose(symbolName, timeframe, shift, period + 1, closes);

	if (copied < period + 1)
		return 0.0;

	double returns[];
	ArrayResize(returns, period);

	double sum = 0.0;

	for (int i = 0; i < period; i++) {
		if (closes[i + 1] == 0.0)
			return 0.0;

		returns[i] = (closes[i] - closes[i + 1]) / closes[i + 1];
		sum += returns[i];
	}

	double mean = sum / period;
	double sumSquaredDiff = 0.0;

	for (int i = 0; i < period; i++) {
		double diff = returns[i] - mean;
		sumSquaredDiff += diff * diff;
	}

	if (period <= 1)
		return 0.0;

	return MathSqrt(sumSquaredDiff / (period - 1));
}

#endif
