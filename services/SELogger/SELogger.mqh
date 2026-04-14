#ifndef __SE_LOGGER_MQH__
#define __SE_LOGGER_MQH__

#include "../../enums/EDebugLevel.mqh"
#include "enums/ELogLevel.mqh"
#include "enums/ELogCode.mqh"

#include "../../interfaces/IRemoteLogger.mqh"

#include "components/LogLevelFilter.mqh"
#include "components/LogPersister.mqh"
#include "components/LogRemoteDispatcher.mqh"
#include "components/LogFormatter.mqh"

class SELogger {
private:
	string prefix;
	static ENUM_DEBUG_LEVEL globalDebugLevel;

public:
	SELogger(string newPrefix = "") {
		prefix = newPrefix;
	}

	void Debug(ENUM_LOG_CODE code, string message) {
		log(LOG_LEVEL_DEBUG, code, message);
	}

	void Error(ENUM_LOG_CODE code, string message) {
		log(LOG_LEVEL_ERROR, code, message);
	}

	void Info(ENUM_LOG_CODE code, string message) {
		log(LOG_LEVEL_INFO, code, message);
	}

	void Success(ENUM_LOG_CODE code, string message) {
		log(LOG_LEVEL_SUCCESS, code, message);
	}

	void Warning(ENUM_LOG_CODE code, string message) {
		log(LOG_LEVEL_WARNING, code, message);
	}

	void Separator(string title) {
		log(LOG_LEVEL_INFO, LOG_CODE_NONE, title + " -------------------------------- ");
	}

	void SetPrefix(string newPrefix) {
		prefix = newPrefix;
	}

	static void SetGlobalDebugLevel(ENUM_DEBUG_LEVEL level) {
		globalDebugLevel = level;
	}

	static void SetRemoteLogger(IRemoteLogger *remoteLoggerInstance) {
		LogRemoteDispatcher::SetRemoteLogger(remoteLoggerInstance);
	}

	static void SetLogSystem(string system) {
		LogRemoteDispatcher::SetLogSystem(system);
	}

	static void GetGlobalEntries(string &result[]) {
		LogPersister::GetAll(result);
	}

	static int GetGlobalEntryCount() {
		return LogPersister::GetCount();
	}

	static void ClearGlobalEntries() {
		LogPersister::Clear();
	}

private:
	void log(ENUM_LOG_LEVEL level, ENUM_LOG_CODE code, string message) {
		if (!LogLevelFilter::IsEnabled(globalDebugLevel)) {
			return;
		}

		string levelLabel = LogLevelToString(level);
		LogRemoteDispatcher::Dispatch(levelLabel, prefix, message);

		if (!LogLevelFilter::ShouldPrint(level, globalDebugLevel)) {
			return;
		}

		Print(LogFormatter::FormatPrintLine(level, code, prefix, message));

		if (!LogLevelFilter::ShouldPersist(globalDebugLevel)) {
			return;
		}

		LogPersister::Append(LogFormatter::FormatPersistedEntry(level, code, prefix, message));
	}
};

ENUM_DEBUG_LEVEL SELogger::globalDebugLevel = DEBUG_LEVEL_ALL;

#endif
