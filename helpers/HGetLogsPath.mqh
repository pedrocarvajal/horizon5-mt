#ifndef __H_GET_LOGS_PATH_MQH__
#define __H_GET_LOGS_PATH_MQH__

#include "../services/SEDateTime/SEDateTime.mqh"

extern SEDateTime dtime;

string GetLogsPath(string symbol) {
	static ulong logSeed = 0;

	if (logSeed == 0)
		logSeed = GetTickCount64();

	return StringFormat(
		"/Logs/%s/%lld_%llu",
		symbol,
		(long)dtime.Timestamp(),
		logSeed
	);
}

#endif
