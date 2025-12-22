#ifndef __IS_MARKET_CLOSED_MQH__
#define __IS_MARKET_CLOSED_MQH__

bool isMarketClosed(string check_symbol, int safety_margin_minutes = 1) {
	datetime current_time = dtime.GetCurrentTime();
	MqlDateTime dt;
	TimeToStruct(current_time, dt);

	ENUM_DAY_OF_WEEK current_day = (ENUM_DAY_OF_WEEK)dt.day_of_week;
	datetime session_start, session_end;
	uint session_index = 0;

	while (SymbolInfoSessionTrade(check_symbol, current_day, session_index, session_start, session_end)) {
		MqlDateTime start_dt, end_dt;
		TimeToStruct(session_start, start_dt);
		TimeToStruct(session_end, end_dt);

		int current_minutes = dt.hour * 60 + dt.min;
		int start_minutes = start_dt.hour * 60 + start_dt.min + safety_margin_minutes;
		int end_minutes = end_dt.hour * 60 + end_dt.min - safety_margin_minutes;

		bool is_overnight_session = (end_minutes <= start_minutes);

		if (is_overnight_session) {
			if (current_minutes >= start_minutes || current_minutes <= end_minutes)
				return false;
		} else {
			if (current_minutes >= start_minutes && current_minutes <= end_minutes)
				return false;
		}

		session_index++;
	}

	return true;
}

#endif
