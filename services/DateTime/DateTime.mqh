#ifndef __DATE_TIME_MQH__
#define __DATE_TIME_MQH__

class DateTime {
public:
	MqlDateTime today;
	MqlDateTime now;
	MqlDateTime yesterday;
	MqlDateTime previous_friday;

	DateTime() {
		Today();
		Now();
		PreviousFriday();
	}

	datetime GetCurrentTime() {
		return TimeCurrent();
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

	MqlDateTime Now() {
		TimeToStruct(
			GetCurrentTime(),
			now
			);

		return now;
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

	MqlDateTime PreviousFriday() {
		int days_to_subtract = (today.day_of_week + 2) % 7;

		if (days_to_subtract == 0)
			days_to_subtract = 7;

		datetime friday_time = StructToTime(Today()) - days_to_subtract * 24 * 60 * 60;

		TimeToStruct(
			friday_time,
			previous_friday
			);

		previous_friday.hour = 0;
		previous_friday.min = 0;
		previous_friday.sec = 0;

		return previous_friday;
	}

	MqlDateTime AddHoursToDate(MqlDateTime &date, int hours) {
		datetime target_time = StructToTime(date) + hours * 60 * 60;
		MqlDateTime result;

		TimeToStruct(target_time, result);

		return result;
	}

	MqlDateTime SubtractHoursFromDate(MqlDateTime &date, int hours) {
		datetime target_time = StructToTime(date) - hours * 60 * 60;
		MqlDateTime result;

		TimeToStruct(target_time, result);

		return result;
	}
};

#endif
