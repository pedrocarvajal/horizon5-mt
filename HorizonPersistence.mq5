#property service
#property copyright "Horizon5"
#property version   "0.15"
#property strict

#include "constants/COHorizonPersistence.mqh"
#include "constants/CODiagnostic.mqh"
#include "constants/COMessageBus.mqh"

#include "enums/EDebugLevel.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"

#include "services/SELogger/SELogger.mqh"
#include "services/SEMessageBus/SEMessageBus.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

SEDateTime dtime;
SELogger logger("Persistence");

input group "General Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "Persistence Settings";
input int PollIntervalMs = 200; // [1] > Poll interval in milliseconds

datetime lastDiagnosticTime = 0;

struct SPendingWrite {
	string filePath;
	int fileFlags;
	string content;
	long messageSequence;
};

void ensureDirectoryExists(string filePath, int fileFlags) {
	int lastSlash = StringFind(filePath, "/");
	int position = lastSlash;

	while (position != -1) {
		lastSlash = position;
		position = StringFind(filePath, "/", lastSlash + 1);
	}

	if (lastSlash <= 0) {
		return;
	}

	string directory = StringSubstr(filePath, 0, lastSlash);
	int commonFlag = (fileFlags & FILE_COMMON) != 0 ? FILE_COMMON : 0;
	FolderCreate(directory, commonFlag);
}

void writeFiles(SPendingWrite &pendingWrites[]) {
	for (int i = 0; i < ArraySize(pendingWrites); i++) {
		ensureDirectoryExists(pendingWrites[i].filePath, pendingWrites[i].fileFlags);

		int handle = FileOpen(pendingWrites[i].filePath, FILE_WRITE | pendingWrites[i].fileFlags);

		if (handle == INVALID_HANDLE) {
			logger.Error(LOG_CODE_PERSISTENCE_SAVE_FAILED, StringFormat(
				"persistence write failed | path='%s' error=%d",
				pendingWrites[i].filePath,
				GetLastError()
			));
		} else {
			FileWriteString(handle, pendingWrites[i].content);
			FileClose(handle);
		}

		SEMessageBus::Ack(MB_CHANNEL_PERSISTENCE, pendingWrites[i].messageSequence);
	}
}

void processMessages(SMessage &messages[], int count) {
	SPendingWrite latestPerPath[];

	for (int i = 0; i < count; i++) {
		if (messages[i].messageType != MB_TYPE_FLUSH) {
			SEMessageBus::Ack(MB_CHANNEL_PERSISTENCE, messages[i].sequence);
			continue;
		}

		JSON::Object payload(messages[i].payloadJson);

		string filePath = payload.getString("filePath");
		int fileFlags = (int)payload.getNumber("fileFlags");
		string content = payload.getString("data");

		if (filePath == "") {
			SEMessageBus::Ack(MB_CHANNEL_PERSISTENCE, messages[i].sequence);
			continue;
		}

		int existingIndex = -1;
		for (int j = 0; j < ArraySize(latestPerPath); j++) {
			if (latestPerPath[j].filePath == filePath) {
				existingIndex = j;
				break;
			}
		}

		if (existingIndex >= 0) {
			SEMessageBus::Ack(MB_CHANNEL_PERSISTENCE, latestPerPath[existingIndex].messageSequence);
			latestPerPath[existingIndex].content = content;
			latestPerPath[existingIndex].fileFlags = fileFlags;
			latestPerPath[existingIndex].messageSequence = messages[i].sequence;
		} else {
			int size = ArraySize(latestPerPath);
			ArrayResize(latestPerPath, size + 1);
			latestPerPath[size].filePath = filePath;
			latestPerPath[size].fileFlags = fileFlags;
			latestPerPath[size].content = content;
			latestPerPath[size].messageSequence = messages[i].sequence;
		}
	}

	writeFiles(latestPerPath);
}

void logDiagnostics() {
	datetime now = TimeCurrent();

	if ((now - lastDiagnosticTime) < DIAGNOSTIC_INTERVAL_SECONDS) {
		return;
	}

	lastDiagnosticTime = now;

	int pendingPersistence = SEMessageBus::GetPendingCount(MB_CHANNEL_PERSISTENCE);

	logger.Info(LOG_CODE_FRAMEWORK_INTERNAL_ERROR, StringFormat(
		"queue diagnostics | persistence=%d",
		pendingPersistence
	));
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!IsLiveTrading()) {
		logger.Warning(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, "service idle | reason='not in live trading mode'");

		while (!IsStopped()) {
			Sleep(5000);
		}

		return 0;
	}

	if (!SEMessageBus::Initialize()) {
		logger.Error(LOG_CODE_FRAMEWORK_INIT_FAILED, "service idle | reason='message bus DLL initialization failed'");
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_PERSISTENCE);
	logger.Info(LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
		"service started | system=HorizonPersistence version=0.15 built='2026-04-15 11:15:54'");

	while (!IsStopped()) {
		SEMessageBus::WaitForMessage(MB_CHANNEL_PERSISTENCE, PollIntervalMs);

		SMessage messages[];
		int count = SEMessageBus::Poll(MB_CHANNEL_PERSISTENCE, messages);

		if (count > 0) {
			processMessages(messages, count);
		}

		logDiagnostics();
	}

	SEMessageBus::UnregisterService(MB_SERVICE_PERSISTENCE);
	SEMessageBus::Shutdown();
	logger.Info(LOG_CODE_FRAMEWORK_INTERNAL_ERROR, "service stopped | system=HorizonPersistence");

	if (SELogger::GetGlobalEntryCount() > 0) {
		string logEntries[];
		SELogger::GetGlobalEntries(logEntries);

		SRReportOfLogs logExporter;
		logExporter.Initialize(GetLogsPath("HorizonPersistence"));
		logExporter.Export("Logs", logEntries);

		SELogger::ClearGlobalEntries();
	}

	return 0;
}
