#ifndef __SE_LOGGER_MQH__
#define __SE_LOGGER_MQH__

#include "../../enums/EDebugLevel.mqh"

class SELogger {
private:
	string prefix;
	string entries[];
	ENUM_DEBUG_LEVEL debugLevel;

	bool shouldPrint(string level) {
		if (debugLevel == DEBUG_LEVEL_NONE)
			return false;

		if (debugLevel == DEBUG_LEVEL_ERRORS || debugLevel == DEBUG_LEVEL_ERRORS_PERSIST)
			return level == "ERROR" || level == "WARNING";

		return true;
	}

	bool shouldPersist() {
		return debugLevel == DEBUG_LEVEL_ERRORS_PERSIST || debugLevel == DEBUG_LEVEL_ALL_PERSIST;
	}

	void log(string level, string message) {
		if (!shouldPrint(level))
			return;

		Print("[", level, "] ", prefix, ": ", message);

		if (!shouldPersist())
			return;

		int size = ArraySize(entries);
		ArrayResize(entries, size + 1);
		entries[size] = StringFormat("[%s] %s: %s", level, prefix, message);
	}

public:
	SELogger() {
		prefix = "";
		debugLevel = DEBUG_LEVEL_ALL;
	}

	SELogger(string newPrefix) {
		prefix = newPrefix;
		debugLevel = DEBUG_LEVEL_ALL;
	}

	void SetPrefix(string newPrefix) {
		prefix = newPrefix;
	}

	void SetDebugLevel(ENUM_DEBUG_LEVEL level) {
		debugLevel = level;
	}

	ENUM_DEBUG_LEVEL GetDebugLevel() {
		return debugLevel;
	}

	int GetEntryCount() {
		return ArraySize(entries);
	}

	void GetEntries(string &result[]) {
		ArrayResize(result, ArraySize(entries));

		for (int i = 0; i < ArraySize(entries); i++) {
			result[i] = entries[i];
		}
	}

	void ClearEntries() {
		ArrayResize(entries, 0);
	}

	void Debug(string message) {
		log("DEBUG", message);
	}

	void Error(string message) {
		log("ERROR", message);
	}

	void Info(string message) {
		log("INFO", message);
	}

	void Warning(string message) {
		log("WARNING", message);
	}

	void Separator(string title) {
		log("INFO", title + " -------------------------------- ");
	}
};

#endif
