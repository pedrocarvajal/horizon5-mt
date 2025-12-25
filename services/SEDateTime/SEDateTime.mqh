#ifndef __SE_DATE_TIME_MQH__
#define __SE_DATE_TIME_MQH__

#include "../SELogger/SELogger.mqh"

class SEDateTime {
private:
	SELogger logger;

	MqlDateTime today;
	MqlDateTime now;
	MqlDateTime yesterday;
	MqlDateTime previousFriday;

public:
	SEDateTime() {
		logger.SetPrefix("SEDateTime");

		Today();
		Now();
		PreviousFriday();
	}

	MqlDateTime AddHoursToDate(MqlDateTime &date, int hours) {
		datetime target_time = StructToTime(date) + hours * 60 * 60;
		MqlDateTime result;

		TimeToStruct(target_time, result);

		return result;
	}

	datetime GetCurrentTime() {
		return TimeCurrent();
	}

	MqlDateTime Now() {
		TimeToStruct(
			GetCurrentTime(),
			now
			);

		return now;
	}

	MqlDateTime PreviousFriday() {
		int daysToSubtract = (today.day_of_week + 2) % 7;

		if (daysToSubtract == 0)
			daysToSubtract = 7;

		datetime fridayTime = StructToTime(Today()) - daysToSubtract * 24 * 60 * 60;

		TimeToStruct(
			fridayTime,
			previousFriday
			);

		previousFriday.hour = 0;
		previousFriday.min = 0;
		previousFriday.sec = 0;

		return previousFriday;
	}

	MqlDateTime SubtractHoursFromDate(MqlDateTime &date, int hours) {
		datetime target_time = StructToTime(date) - hours * 60 * 60;
		MqlDateTime result;

		TimeToStruct(target_time, result);

		return result;
	}

	MqlDateTime Today() {
		TimeToStruct(
			TimeCurrent(),
			today
			);

		today.hour = 0;
		today.min = 0;
		today.sec = 0;

		return today;
	}

	MqlDateTime Yesterday() {
		TimeToStruct(
			StructToTime(Today()) - 24 * 60 * 60,
			yesterday
			);

		yesterday.hour = 0;
		yesterday.min = 0;
		yesterday.sec = 0;

		return yesterday;
	}

	MqlDateTime GetNow() {
		return now;
	}

	MqlDateTime GetPreviousFriday() {
		return previousFriday;
	}

	MqlDateTime GetToday() {
		return today;
	}

	MqlDateTime GetYesterday() {
		return yesterday;
	}
};

#endif
