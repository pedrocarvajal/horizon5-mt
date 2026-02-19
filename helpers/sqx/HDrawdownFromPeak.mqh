#ifndef __SQX_DRAWDOWN_FROM_PEAK_MQH__
#define __SQX_DRAWDOWN_FROM_PEAK_MQH__

double DrawdownFromPeak(string symbolName, ENUM_TIMEFRAMES timeframe, int period, int shift) {
	double closes[];
	ArraySetAsSeries(closes, true);

	int copied = CopyClose(symbolName, timeframe, shift, period + 1, closes);

	if (copied < period + 1) {
		return 0.0;
	}

	int peakIndex = ArrayMaximum(closes, 0, copied);
	double peak = closes[peakIndex];

	if (peak <= 0.0) {
		return 0.0;
	}

	return (peak - closes[0]) / peak;
}

#endif
