#ifndef __SE_RATES_MQH__
#define __SE_RATES_MQH__

#include "../SELogger/SELogger.mqh"

class SERates {
private:
	SELogger logger;

public:
	SERates() {
		logger.SetPrefix("SERates");
	}

	int Get(string symbol, ENUM_TIMEFRAMES timeframe, MqlDateTime &fromDate,
		MqlDateTime &toDate, MqlRates &candles[]) {
		ArrayFree(candles);
		ArraySetAsSeries(candles, true);

		datetime startTime = StructToTime(fromDate);
		datetime endTime = StructToTime(toDate);

		int wasCopied = CopyRates(symbol, timeframe, startTime, endTime,
			candles);

		if (wasCopied <= 0) {
			logger.Error(StringFormat(
				"Failed to copy rates for %s",
				symbol));
			return -1;
		}

		return wasCopied;
	}
};

#endif
