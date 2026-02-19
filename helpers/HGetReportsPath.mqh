#ifndef __H_GET_REPORTS_PATH_MQH__
#define __H_GET_REPORTS_PATH_MQH__

#include "../services/SEDateTime/SEDateTime.mqh"

extern SEDateTime dtime;

string GetReportsPath(string symbol) {
	static ulong reportSeed = 0;

	if (reportSeed == 0) {
		reportSeed = GetTickCount64();
	}

	return StringFormat(
		"/Reports/%s/%lld_%llu",
		symbol,
		(long)dtime.Timestamp(),
		reportSeed
	);
}

#endif
