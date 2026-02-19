#ifndef __SE_LOGGER_MQH__
#define __SE_LOGGER_MQH__

#include "../../enums/EDebugLevel.mqh"
#include "../../helpers/HIsLiveTrading.mqh"
#include "../../interfaces/IRemoteLogger.mqh"

class SELogger {
private:
	string prefix;
	string entries[];
	ENUM_DEBUG_LEVEL debugLevel;
	static IRemoteLogger *remoteLogger;
	static bool isSendingToRemote;

public:
	SELogger(string newPrefix = "") {
		prefix = newPrefix;
		debugLevel = DEBUG_LEVEL_ALL;
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

	ENUM_DEBUG_LEVEL GetDebugLevel() {
		return debugLevel;
	}

	void GetEntries(string &result[]) {
		ArrayResize(result, ArraySize(entries));

		for (int i = 0; i < ArraySize(entries); i++) {
			result[i] = entries[i];
		}
	}

	int GetEntryCount() {
		return ArraySize(entries);
	}

	void Info(string message) {
		log("INFO", message);
	}

	void Separator(string title) {
		log("INFO", title + " -------------------------------- ");
	}

	void SetDebugLevel(ENUM_DEBUG_LEVEL level) {
		debugLevel = level;
	}

	void SetPrefix(string newPrefix) {
		prefix = newPrefix;
	}

	static void SetRemoteLogger(IRemoteLogger *logger) {
		remoteLogger = logger;
	}

	void Warning(string message) {
		log("WARNING", message);
	}

private:
	void log(string level, string message) {
		if (!shouldPrint(level)) {
			return;
		}

		Print("[", level, "] ", prefix, ": ", message);
		sendToRemote(level, message);

		if (!shouldPersist()) {
			return;
		}

		int size = ArraySize(entries);
		ArrayResize(entries, size + 1, size + 64);
		entries[size] = StringFormat("[%s] %s: %s", level, prefix, message);
	}

	void sendToRemote(string level, string message) {
		if (isSendingToRemote || remoteLogger == NULL || !IsLiveTrading()) {
			return;
		}

		isSendingToRemote = true;
		remoteLogger.InsertLog(level, prefix + ": " + message);
		isSendingToRemote = false;
	}

	bool shouldPersist() {
		return debugLevel == DEBUG_LEVEL_ERRORS_PERSIST || debugLevel == DEBUG_LEVEL_ALL_PERSIST;
	}

	bool shouldPrint(string level) {
		if (debugLevel == DEBUG_LEVEL_NONE) {
			return false;
		}

		if (debugLevel == DEBUG_LEVEL_ERRORS || debugLevel == DEBUG_LEVEL_ERRORS_PERSIST) {
			return level == "ERROR" || level == "WARNING";
		}

		return true;
	}
};

IRemoteLogger *SELogger::remoteLogger = NULL;
bool SELogger::isSendingToRemote = false;

#endif
