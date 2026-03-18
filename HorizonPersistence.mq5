#property service
#property copyright "Horizon5"
#property version   "1.04"
#property strict

#include "enums/EDebugLevel.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"

#include "services/SELogger/SELogger.mqh"
#include "services/SEMessageBus/SEMessageBus.mqh"
#include "services/SEMessageBus/SEMessageBusChannels.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

#define SERVICE_VERSION "1.0.1"
#define MESSAGE_TYPE_FLUSH "flush"
#define DIAGNOSTIC_INTERVAL_SECONDS 300

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
			logger.Error(StringFormat(
				"Cannot write '%s' - Error: %d",
				pendingWrites[i].filePath, GetLastError()
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
		if (messages[i].messageType != MESSAGE_TYPE_FLUSH) {
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

	logger.Info(StringFormat(
		"Queue diagnostics | persistence=%d",
		pendingPersistence
	));
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!IsLiveTrading()) {
		logger.Warning("Not in live trading mode, service idle");

		while (!IsStopped()) {
			Sleep(5000);
		}

		return 0;
	}

	if (!SEMessageBus::Initialize()) {
		logger.Error("MessageBus DLL initialization failed");
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_PERSISTENCE);
	logger.Info("Service started | v" + SERVICE_VERSION + " | built " + (string)__DATETIME__);

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
	logger.Info("Service stopped");

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
