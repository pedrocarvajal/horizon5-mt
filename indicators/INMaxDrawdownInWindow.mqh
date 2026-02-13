#ifndef __IN_MAX_DRAWDOWN_IN_WINDOW_MQH__
#define __IN_MAX_DRAWDOWN_IN_WINDOW_MQH__

double MaxDrawdownInWindow(string symbolName, ENUM_TIMEFRAMES timeframe, int period, int shift) {
	double closes[];
	ArraySetAsSeries(closes, false);

	int copied = CopyClose(symbolName, timeframe, shift, period + 1, closes);

	if (copied < period + 1)
		return 0.0;

	double peak = closes[0];
	double maxDrawdown = 0.0;

	for (int i = 1; i < copied; i++) {
		if (closes[i] > peak)
			peak = closes[i];

		double drawdown = (closes[i] - peak) / peak;

		if (drawdown < maxDrawdown)
			maxDrawdown = drawdown;
	}

	return maxDrawdown;
}

#endif
