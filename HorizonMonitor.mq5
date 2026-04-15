#property service
#property copyright "Horizon5"
#property version   "0.16"
#property strict

#include "constants/COHorizonMonitor.mqh"
#include "constants/CODiagnostic.mqh"
#include "constants/COMessageBus.mqh"

#include "enums/EDebugLevel.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "helpers/HGetSystemName.mqh"

#include "services/SELogger/SELogger.mqh"
#include "services/SEMessageBus/SEMessageBus.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

#include "integrations/HorizonMonitor/HorizonMonitor.mqh"

SEDateTime dtime;
SELogger monitorLogger("HorizonMonitor");
HorizonMonitor horizonMonitor;

input group "General Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "HorizonMonitor Integration";
input string HorizonMonitorUrl = ""; // [1] > HorizonMonitor base URL
input string HorizonMonitorEmail = ""; // [1] > HorizonMonitor email (required)
input string HorizonMonitorPassword = ""; // [1] > HorizonMonitor password (required)

datetime lastDiagnosticTime = 0;
datetime lastHeartbeatTime = 0;

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
		if (messages[i].messageType != MB_TYPE_HTTP_POST) {
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

void sendHeartbeat() {
	datetime now = TimeCurrent();

	if ((now - lastHeartbeatTime) < HEARTBEAT_INTERVAL_SECONDS) {
		return;
	}

	lastHeartbeatTime = now;

	horizonMonitor.StoreSystemHeartbeat(GetSystemName(SYSTEM_MONITOR_SERVICE));
}

void logDiagnostics() {
	datetime now = TimeCurrent();

	if ((now - lastDiagnosticTime) < DIAGNOSTIC_INTERVAL_SECONDS) {
		return;
	}

	lastDiagnosticTime = now;

	int pendingConnector = SEMessageBus::GetPendingCount(MB_CHANNEL_CONNECTOR);

	monitorLogger.Info(
		LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
		StringFormat(
			"queue diagnostics | connector=%d",
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
		monitorLogger.Warning(
			LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
			"service idle | reason='monitor initialization failed'"
		);
		return 0;
	}

	if (horizonMonitor.IsEnabled()) {
		if (!horizonMonitor.UpsertAccount()) {
			monitorLogger.Error(
				LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
				"service idle | reason='account registration failed'"
			);
			return 0;
		}

		SELogger::SetRemoteLogger(GetPointer(horizonMonitor));
		sendHeartbeat();
	}

	if (!SEMessageBus::Initialize()) {
		monitorLogger.Error(
			LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
			"service idle | reason='message bus DLL initialization failed'"
		);
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_MONITOR);
	monitorLogger.Info(
		LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
		"service started | system=HorizonMonitor version=0.16 built='2026-04-15 14:14:55'"
	);

	while (!IsStopped()) {
		SEMessageBus::WaitForMessage(MB_CHANNEL_CONNECTOR, HORIZON_MONITOR_POLL_INTERVAL_MILLISECONDS);

		processConnectorMessages();
		sendHeartbeat();
		logDiagnostics();
	}

	SELogger::SetRemoteLogger(NULL);
	SEMessageBus::UnregisterService(MB_SERVICE_MONITOR);
	SEMessageBus::Shutdown();
	monitorLogger.Info(
		LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
		"service stopped | system=HorizonMonitor"
	);

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
