#ifndef __E_LOG_LEVEL_MQH__
#define __E_LOG_LEVEL_MQH__

enum ENUM_LOG_LEVEL {
	LOG_LEVEL_DEBUG,
	LOG_LEVEL_INFO,
	LOG_LEVEL_SUCCESS,
	LOG_LEVEL_WARNING,
	LOG_LEVEL_ERROR
};

string LogLevelToString(ENUM_LOG_LEVEL level) {
	switch (level) {
	case LOG_LEVEL_DEBUG:   return "DEBUG";
	case LOG_LEVEL_INFO:    return "INFO";
	case LOG_LEVEL_SUCCESS: return "SUCCESS";
	case LOG_LEVEL_WARNING: return "WARNING";
	case LOG_LEVEL_ERROR:   return "ERROR";
	default:                return "UNKNOWN";
	}
}

#endif
