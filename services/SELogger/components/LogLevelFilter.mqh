#ifndef __LOG_LEVEL_FILTER_MQH__
#define __LOG_LEVEL_FILTER_MQH__

#include "../../../enums/EDebugLevel.mqh"
#include "../enums/ELogLevel.mqh"

class LogLevelFilter {
public:
	static bool ShouldPrint(ENUM_LOG_LEVEL level, ENUM_DEBUG_LEVEL debugLevel) {
		if (debugLevel == DEBUG_LEVEL_NONE) {
			return false;
		}

		if (debugLevel == DEBUG_LEVEL_ERRORS || debugLevel == DEBUG_LEVEL_ERRORS_PERSIST) {
			return level == LOG_LEVEL_ERROR || level == LOG_LEVEL_WARNING;
		}

		return true;
	}

	static bool ShouldPersist(ENUM_DEBUG_LEVEL debugLevel) {
		return debugLevel == DEBUG_LEVEL_ERRORS_PERSIST
		       || debugLevel == DEBUG_LEVEL_ALL_PERSIST;
	}

	static bool IsEnabled(ENUM_DEBUG_LEVEL debugLevel) {
		return debugLevel != DEBUG_LEVEL_NONE;
	}
};

#endif
