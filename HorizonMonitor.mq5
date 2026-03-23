#property service
#property copyright "Horizon5"
#property version   "0.02"
#property strict

#include "enums/EDebugLevel.mqh"
#include "enums/ELogSystem.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"

#include "services/SELogger/SELogger.mqh"
#include "services/SEMessageBus/SEMessageBus.mqh"
#include "services/SEMessageBus/SEMessageBusChannels.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

#include "integrations/HorizonMonitor/HorizonMonitor.mqh"


#define MESSAGE_TYPE_HTTP_POST "http_post"
#define API_ORDER_PATH_PREFIX  "api/v1/order"

#define DIAGNOSTIC_INTERVAL_SECONDS 300

SEDateTime dtime;
SELogger monitorLogger("HorizonMonitor");
HorizonMonitor horizonMonitor;

input group "General Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "HorizonMonitor Integration";
input string HorizonMonitorUrl = ""; // [1] > HorizonMonitor base URL
input string HorizonMonitorEmail = ""; // [1] > HorizonMonitor email (required)
input string HorizonMonitorPassword = ""; // [1] > HorizonMonitor password (required)

#define POLL_INTERVAL_MS 100

datetime lastDiagnosticTime = 0;

bool isOrderEndpoint(string path) {
	return StringFind(path, API_ORDER_PATH_PREFIX) >= 0;
}

string extractPath(SMessage &message) {
	JSON::Object payload(message.payloadJson);
	return payload.getString("path");
}

void processConnectorMessages() {
	SMessage messages[];
	int count = SEMessageBus::Poll(MB_CHANNEL_CONNECTOR, messages);

	if (count == 0) {
		return;
	}

	SMessage priorityMessages[];
	SMessage normalMessages[];
	string priorityPaths[];
	string normalPaths[];

	for (int i = 0; i < count; i++) {
		if (messages[i].messageType != MESSAGE_TYPE_HTTP_POST) {
			SEMessageBus::Ack(MB_CHANNEL_CONNECTOR, messages[i].sequence);
			continue;
		}

		string path = extractPath(messages[i]);

		if (path == "") {
			SEMessageBus::Ack(MB_CHANNEL_CONNECTOR, messages[i].sequence);
			continue;
		}

		if (isOrderEndpoint(path)) {
			int size = ArraySize(priorityMessages);
			ArrayResize(priorityMessages, size + 1);
			ArrayResize(priorityPaths, size + 1);
			priorityMessages[size] = messages[i];
			priorityPaths[size] = path;
		} else {
			int size = ArraySize(normalMessages);
			ArrayResize(normalMessages, size + 1);
			ArrayResize(normalPaths, size + 1);
			normalMessages[size] = messages[i];
			normalPaths[size] = path;
		}
	}

	for (int i = 0; i < ArraySize(priorityMessages); i++) {
		executeMessage(priorityMessages[i], priorityPaths[i]);
	}

	for (int i = 0; i < ArraySize(normalMessages); i++) {
		executeMessage(normalMessages[i], normalPaths[i]);
	}
}

void executeMessage(SMessage &message, string path) {
	JSON::Object payload(message.payloadJson);
	JSON::Object *bodyObject = payload.getObject("body");

	if (bodyObject == NULL) {
		SEMessageBus::Ack(MB_CHANNEL_CONNECTOR, message.sequence);
		return;
	}

	horizonMonitor.PostDirect(path, *bodyObject);

	SEMessageBus::Ack(MB_CHANNEL_CONNECTOR, message.sequence);
}

void logDiagnostics() {
	datetime now = TimeCurrent();

	if ((now - lastDiagnosticTime) < DIAGNOSTIC_INTERVAL_SECONDS) {
		return;
	}

	lastDiagnosticTime = now;

	int pendingConnector = SEMessageBus::GetPendingCount(MB_CHANNEL_CONNECTOR);

	monitorLogger.Info(StringFormat(
		"Queue diagnostics | connector=%d",
		pendingConnector
	));
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);
	SELogger::SetLogSystem(LOG_SYSTEM_HORIZON5_MONITOR_SERVICE);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!horizonMonitor.Initialize(HorizonMonitorUrl, HorizonMonitorEmail, HorizonMonitorPassword, IsLiveTrading())) {
		monitorLogger.Warning("HorizonMonitor initialization failed, service idle");
		return 0;
	}

	if (horizonMonitor.IsEnabled()) {
		horizonMonitor.UpsertAccount();
		SELogger::SetRemoteLogger(GetPointer(horizonMonitor));
	}

	if (!SEMessageBus::Initialize()) {
		monitorLogger.Error("MessageBus DLL initialization failed");
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_MONITOR);
	monitorLogger.Info("Service started | v" + "1.00" + " | built " + (string)__DATETIME__);

	while (!IsStopped()) {
		SEMessageBus::WaitForMessage(MB_CHANNEL_CONNECTOR, POLL_INTERVAL_MS);

		processConnectorMessages();
		logDiagnostics();
	}

	SELogger::SetRemoteLogger(NULL);
	SEMessageBus::UnregisterService(MB_SERVICE_MONITOR);
	SEMessageBus::Shutdown();
	monitorLogger.Info("Service stopped");

	if (SELogger::GetGlobalEntryCount() > 0) {
		string logEntries[];
		SELogger::GetGlobalEntries(logEntries);

		SRReportOfLogs logExporter;
		logExporter.Initialize(GetLogsPath("HorizonMonitor"));
		logExporter.Export("Logs", logEntries);

		SELogger::ClearGlobalEntries();
	}

	return 0;
}
