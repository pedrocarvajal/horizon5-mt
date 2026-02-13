#ifndef __SE_DATE_TIME_MQH__
#define __SE_DATE_TIME_MQH__

#include "structs/SDateTime.mqh"

class SEDateTime {
private:
	SDateTime current;
	SDateTime today;

	SDateTime fromMqlDateTime(MqlDateTime &mql, datetime ts) {
		SDateTime result;

		result.year = mql.year;
		result.month = mql.mon;
		result.day = mql.day;
		result.hour = mql.hour;
		result.minute = mql.min;
		result.second = mql.sec;
		result.dayOfWeek = mql.day_of_week;
		result.dayOfYear = mql.day_of_year;
		result.timestamp = ts;

		return result;
	}

public:
	SEDateTime() {
		Now();
		Today();
	}

	SDateTime FromTimestamp(datetime ts) {
		MqlDateTime mql;
		TimeToStruct(ts, mql);
		return fromMqlDateTime(mql, ts);
	}

	datetime Timestamp() {
		return TimeTradeServer();
	}

	SDateTime Now() {
		datetime ts = TimeTradeServer();
		MqlDateTime mql;

		TimeToStruct(ts, mql);
		current = fromMqlDateTime(mql, ts);

		return current;
	}

	SDateTime Today() {
		datetime ts = TimeTradeServer();
		MqlDateTime mql;

		TimeToStruct(ts, mql);

		mql.hour = 0;
		mql.min = 0;
		mql.sec = 0;

		today = fromMqlDateTime(mql, StructToTime(mql));

		return today;
	}
};

#endif
