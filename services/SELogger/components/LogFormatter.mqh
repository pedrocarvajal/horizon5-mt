#ifndef __LOG_FORMATTER_MQH__
#define __LOG_FORMATTER_MQH__

#include "../enums/ELogLevel.mqh"
#include "../enums/ELogCode.mqh"

class LogFormatter {
public:
	static string FormatPrintLine(ENUM_LOG_LEVEL level, ENUM_LOG_CODE code, string prefix, string message) {
		return StringFormat("[%s] [%s] %s: %s",
			LogLevelToString(level),
			FormatLogCode(code),
			prefix,
			message
		);
	}

	static string FormatPersistedEntry(ENUM_LOG_LEVEL level, ENUM_LOG_CODE code, string prefix, string message) {
		return FormatPrintLine(level, code, prefix, message);
	}

	static string FormatLogCode(ENUM_LOG_CODE code) {
		if (code == LOG_CODE_NONE) {
			return "-";
		}

		return IntegerToString((int)code);
	}
};

#endif
