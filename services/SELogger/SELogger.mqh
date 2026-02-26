#ifndef __SE_LOGGER_MQH__
#define __SE_LOGGER_MQH__

#include "../../enums/EDebugLevel.mqh"
#include "../../helpers/HIsLiveTrading.mqh"
#include "../../interfaces/IRemoteLogger.mqh"

class SELogger {
private:
	string prefix;
	static ENUM_DEBUG_LEVEL globalDebugLevel;
	static string globalEntries[];
	static IRemoteLogger *remoteLogger;
	static bool isSendingToRemote;

public:
	SELogger(string newPrefix = "") {
		prefix = newPrefix;
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

	void Separator(string title) {
		log("INFO", title + " -------------------------------- ");
	}

	void SetPrefix(string newPrefix) {
		prefix = newPrefix;
	}

	void Warning(string message) {
		log("WARNING", message);
	}

	static void SetGlobalDebugLevel(ENUM_DEBUG_LEVEL level) {
		globalDebugLevel = level;
	}

	static void SetRemoteLogger(IRemoteLogger *logger) {
		remoteLogger = logger;
	}

	static void GetGlobalEntries(string &result[]) {
		int size = ArraySize(globalEntries);
		ArrayResize(result, size);

		for (int i = 0; i < size; i++) {
			result[i] = globalEntries[i];
		}
	}

	static int GetGlobalEntryCount() {
		return ArraySize(globalEntries);
	}

	static void ClearGlobalEntries() {
		ArrayResize(globalEntries, 0);
	}

private:
	void log(string level, string message) {
		if (globalDebugLevel == DEBUG_LEVEL_NONE) {
			return;
		}

		sendToRemote(level, message);

		if (!shouldPrint(level)) {
			return;
		}

		Print("[", level, "] ", prefix, ": ", message);

		if (!shouldPersist()) {
			return;
		}

		int size = ArraySize(globalEntries);
		ArrayResize(globalEntries, size + 1, size + 64);
		globalEntries[size] = StringFormat("[%s] %s: %s", level, prefix, message);
	}

	void sendToRemote(string level, string message) {
		if (isSendingToRemote || remoteLogger == NULL || !IsLiveTrading()) {
			return;
		}

		isSendingToRemote = true;
		remoteLogger.InsertLog(level, prefix + ": " + message);
		isSendingToRemote = false;
	}

	static bool shouldPersist() {
		return globalDebugLevel == DEBUG_LEVEL_ERRORS_PERSIST || globalDebugLevel == DEBUG_LEVEL_ALL_PERSIST;
	}

	static bool shouldPrint(string level) {
		if (globalDebugLevel == DEBUG_LEVEL_NONE) {
			return false;
		}

		if (globalDebugLevel == DEBUG_LEVEL_ERRORS || globalDebugLevel == DEBUG_LEVEL_ERRORS_PERSIST) {
			return level == "ERROR" || level == "WARNING";
		}

		return true;
	}
};

ENUM_DEBUG_LEVEL SELogger::globalDebugLevel = DEBUG_LEVEL_ALL;
string SELogger::globalEntries[];
IRemoteLogger *SELogger::remoteLogger = NULL;
bool SELogger::isSendingToRemote = false;

#endif
