#ifndef __LOG_REMOTE_DISPATCHER_MQH__
#define __LOG_REMOTE_DISPATCHER_MQH__

#include "../../../interfaces/IRemoteLogger.mqh"

#include "../../../helpers/HIsLiveEnvironment.mqh"

#include "LogFormatter.mqh"

class LogRemoteDispatcher {
private:
	static IRemoteLogger * remoteLogger;
	static string logSystem;
	static bool isDispatching;

public:
	static void SetRemoteLogger(IRemoteLogger *instance) {
		remoteLogger = instance;
	}

	static void SetLogSystem(string system) {
		logSystem = system;
	}

	static void Dispatch(string level, string prefix, string message) {
		if (isDispatching || remoteLogger == NULL || !IsLiveEnvironment()) {
			return;
		}

		isDispatching = true;
		remoteLogger.StoreLog(logSystem, level, LogFormatter::FormatRemoteLine(prefix, message));
		isDispatching = false;
	}
};

IRemoteLogger *LogRemoteDispatcher::remoteLogger = NULL;
string LogRemoteDispatcher::logSystem = "";
bool LogRemoteDispatcher::isDispatching = false;

#endif
