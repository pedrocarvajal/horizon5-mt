#ifndef __S_DATE_TIME_MQH__
#define __S_DATE_TIME_MQH__

struct SDateTime {
	int year;
	int month;
	int day;
	int hour;
	int minute;
	int second;
	int dayOfWeek;
	int dayOfYear;
	datetime timestamp;

	MqlDateTime ToMql() {
		MqlDateTime mql;

		mql.year = year;
		mql.mon = month;
		mql.day = day;
		mql.hour = hour;
		mql.min = minute;
		mql.sec = second;
		mql.day_of_week = dayOfWeek;
		mql.day_of_year = dayOfYear;

		return mql;
	}
};

#endif
