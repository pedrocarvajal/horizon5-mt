#ifndef __SQX_DAILY_PERFORMANCE_MQH__
#define __SQX_DAILY_PERFORMANCE_MQH__

double DailyPerformance(string symbolName, ENUM_TIMEFRAMES timeframe, int shift) {
	double closes[];
	ArraySetAsSeries(closes, true);

	int copied = CopyClose(symbolName, timeframe, shift, 2, closes);

	if (copied < 2)
		return 0.0;

	if (closes[1] == 0.0)
		return 0.0;

	return (closes[0] - closes[1]) / closes[1];
}

#endif
