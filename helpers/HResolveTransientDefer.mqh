#ifndef __H_RESOLVE_TRANSIENT_DEFER_MQH__
#define __H_RESOLVE_TRANSIENT_DEFER_MQH__

#include "../constants/COTime.mqh"
#include "../constants/COTransientDefer.mqh"

#include "../services/SEDateTime/SEDateTime.mqh"

#include "./HIsMarketClosed.mqh"

extern SEDateTime dtime;

int ResolveTransientDeferSeconds(uint retcode, string symbol) {
	if (retcode == TRADE_RETCODE_MARKET_CLOSED) {
		MqlDateTime now;
		TimeToStruct(dtime.Timestamp(), now);

		bool isWeekend = (now.day_of_week == SATURDAY || now.day_of_week == SUNDAY);

		if (!isWeekend) {
			return TRANSIENT_DEFER_MARKET_CLOSED_WEEKDAY_SECONDS;
		}

		SMarketStatus nextSession = GetMarketStatus(symbol);
		return nextSession.opensInSeconds > 0
			? nextSession.opensInSeconds
			: SECONDS_IN_24_HOURS;
	}

	if (retcode == TRADE_RETCODE_CONNECTION) {
		return TRANSIENT_DEFER_CONNECTION_SECONDS;
	}

	if (retcode == TRADE_RETCODE_TOO_MANY_REQUESTS) {
		return TRANSIENT_DEFER_TOO_MANY_REQUESTS_SECONDS;
	}

	if (retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_PRICE_CHANGED) {
		return TRANSIENT_DEFER_REQUOTE_SECONDS;
	}

	return TRANSIENT_DEFER_DEFAULT_SECONDS;
}

#endif
