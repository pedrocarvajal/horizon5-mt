#ifndef __H_IS_MARKET_CLOSED_MQH__
#define __H_IS_MARKET_CLOSED_MQH__

#include "../services/SEDateTime/SEDateTime.mqh"
#include "../structs/SMarketStatus.mqh"
#include "../constants/time.mqh"

extern SEDateTime dtime;

SMarketStatus GetMarketStatus(string checkSymbol, int safetyMarginMinutes = 0) {
	SMarketStatus status;
	status.isClosed = true;
	status.opensInSeconds = 0;

	datetime currentTime = dtime.Timestamp();
	MqlDateTime dt;
	TimeToStruct(currentTime, dt);

	int currentMinutes = dt.hour * 60 + dt.min;
	int currentSeconds = currentMinutes * 60 + dt.sec;

	for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
		ENUM_DAY_OF_WEEK checkDay = (ENUM_DAY_OF_WEEK)((dt.day_of_week + dayOffset) % 7);
		datetime sessionStart, sessionEnd;
		uint sessionIndex = 0;

		while (SymbolInfoSessionTrade(checkSymbol, checkDay, sessionIndex,
			sessionStart, sessionEnd)) {
			MqlDateTime startDt, endDt;
			TimeToStruct(sessionStart, startDt);
			TimeToStruct(sessionEnd, endDt);

			int startMinutes = startDt.hour * 60 + startDt.min + safetyMarginMinutes;
			int endMinutes = endDt.hour * 60 + endDt.min - safetyMarginMinutes;
			int startSeconds = startMinutes * 60;
			int endSeconds = endMinutes * 60;

			if (dayOffset == 0) {
				bool isOvernightSession = (endMinutes <= startMinutes);

				if (isOvernightSession) {
					if (currentMinutes >= startMinutes ||
					    currentMinutes <= endMinutes) {
						status.isClosed = false;
						status.opensInSeconds = 0;
						return status;
					}
				} else {
					if (currentMinutes >= startMinutes &&
					    currentMinutes <= endMinutes) {
						status.isClosed = false;
						status.opensInSeconds = 0;
						return status;
					}
				}

				if (currentSeconds < startSeconds) {
					status.opensInSeconds = startSeconds - currentSeconds;
					return status;
				}
			} else {
				int secondsUntilMidnight = SECONDS_IN_24_HOURS - currentSeconds;
				int secondsFromPreviousDays = (dayOffset - 1) * SECONDS_IN_24_HOURS;
				status.opensInSeconds = secondsUntilMidnight + secondsFromPreviousDays + startSeconds;
				return status;
			}

			sessionIndex++;
		}
	}

	status.opensInSeconds = SECONDS_IN_24_HOURS;
	return status;
}

bool IsMarketClosed(string checkSymbol, int safetyMarginMinutes = 1) {
	return GetMarketStatus(checkSymbol, safetyMarginMinutes).isClosed;
}

#endif
