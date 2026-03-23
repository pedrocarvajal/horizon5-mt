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

#include "integrations/HorizonGateway/HorizonGateway.mqh"


#define MESSAGE_TYPE_ACK_EVENT "ack_event"

#define DIAGNOSTIC_INTERVAL_SECONDS 300

string EVENT_KEYS_TRADING[] = { "post.order", "delete.order", "put.order", "get.orders" };
string EVENT_KEYS_SERVICE[] = { "get.account.info", "get.assets", "get.strategies", "get.ticker", "get.klines", "patch.account.disable", "patch.account.enable" };

SEDateTime dtime;
SELogger gatewayLogger("HorizonGateway");
HorizonGateway horizonGateway;

input group "General Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "HorizonGateway Integration";
input string HorizonGatewayUrl = ""; // [1] > HorizonGateway base URL
input string HorizonGatewayEmail = ""; // [1] > HorizonGateway email (required)
input string HorizonGatewayPassword = ""; // [1] > HorizonGateway password (required)

#define EVENT_POLL_INTERVAL    3
#define MAX_EVENTS_PER_POLL    10

datetime lastDiagnosticTime = 0;

string joinKeys(string &keys[]) {
	string result = "";

	for (int i = 0; i < ArraySize(keys); i++) {
		if (i > 0) {
			result += ",";
		}

		result += keys[i];
	}

	return result;
}

void consumeAndForwardTradingEvents() {
	string tradingKeys = joinKeys(EVENT_KEYS_TRADING);

	SGatewayEvent tradingEvents[];
	int tradingCount = horizonGateway.ConsumeEvents(tradingKeys, "", tradingEvents, MAX_EVENTS_PER_POLL, 0, false);

	if (tradingCount > 0) {
		gatewayLogger.Info(StringFormat("Consumed %d trading events", tradingCount));
	}

	for (int i = 0; i < tradingCount; i++) {
		JSON::Object eventPayload;
		tradingEvents[i].ToJson(eventPayload);
		bool sent = SEMessageBus::Send(MB_CHANNEL_EVENTS_IN, tradingEvents[i].key, eventPayload);
		gatewayLogger.Info(StringFormat(
			"Event forwarded to EA | %s | strategy=%d | symbol=%s | id=%s | sent=%s",
			tradingEvents[i].key, tradingEvents[i].strategyId,
			tradingEvents[i].symbol, tradingEvents[i].id,
			sent ? "ok" : "FAILED"
		));
	}
}

void consumeAndForwardServiceEvents() {
	string serviceKeys = joinKeys(EVENT_KEYS_SERVICE);

	SGatewayEvent serviceEvents[];
	int serviceCount = horizonGateway.ConsumeEvents(serviceKeys, "", serviceEvents, MAX_EVENTS_PER_POLL, 0, false);

	for (int i = 0; i < serviceCount; i++) {
		JSON::Object eventPayload;
		serviceEvents[i].ToJson(eventPayload);
		SEMessageBus::Send(MB_CHANNEL_EVENTS_SERVICE, serviceEvents[i].key, eventPayload);
		gatewayLogger.Info(StringFormat(
			"Service event forwarded to EA | %s | id=%s",
			serviceEvents[i].key, serviceEvents[i].id
		));
	}
}

void processAckResponses() {
	static double cachedAckCounter = 0;

	if (!SEMessageBus::HasChanges(MB_CHANNEL_EVENTS_OUT, cachedAckCounter)) {
		return;
	}

	SMessage ackMessages[];
	int ackCount = SEMessageBus::Poll(MB_CHANNEL_EVENTS_OUT, ackMessages);

	for (int i = 0; i < ackCount; i++) {
		if (ackMessages[i].messageType != MESSAGE_TYPE_ACK_EVENT) {
			SEMessageBus::Ack(MB_CHANNEL_EVENTS_OUT, ackMessages[i].sequence);
			continue;
		}

		JSON::Object payload(ackMessages[i].payloadJson);

		string eventId = payload.getString("event_id");
		JSON::Object *responseObject = payload.getObject("response");

		if (eventId == "" || responseObject == NULL) {
			SEMessageBus::Ack(MB_CHANNEL_EVENTS_OUT, ackMessages[i].sequence);
			continue;
		}

		string responseJson = responseObject.toString();
		JSON::Object responseBody(responseJson);
		horizonGateway.AckEventDirect(eventId, responseBody);

		gatewayLogger.Info(StringFormat("Ack forwarded | event=%s", eventId));
		SEMessageBus::Ack(MB_CHANNEL_EVENTS_OUT, ackMessages[i].sequence);
	}
}

void logDiagnostics() {
	datetime now = TimeCurrent();

	if ((now - lastDiagnosticTime) < DIAGNOSTIC_INTERVAL_SECONDS) {
		return;
	}

	lastDiagnosticTime = now;

	int pendingEventsIn = SEMessageBus::GetPendingCount(MB_CHANNEL_EVENTS_IN);
	int pendingEventsOut = SEMessageBus::GetPendingCount(MB_CHANNEL_EVENTS_OUT);
	int pendingEventsService = SEMessageBus::GetPendingCount(MB_CHANNEL_EVENTS_SERVICE);

	gatewayLogger.Info(StringFormat(
		"Queue diagnostics | events_in=%d | events_out=%d | events_service=%d",
		pendingEventsIn, pendingEventsOut, pendingEventsService
	));
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);
	SELogger::SetLogSystem(LOG_SYSTEM_HORIZON5_GATEWAY_SERVICE);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!horizonGateway.Initialize(HorizonGatewayUrl, HorizonGatewayEmail, HorizonGatewayPassword, IsLiveTrading())) {
		gatewayLogger.Warning("HorizonGateway initialization failed, service idle");
		return 0;
	}

	if (horizonGateway.IsEnabled()) {
		horizonGateway.UpsertAccount();
	}

	if (!SEMessageBus::Initialize()) {
		gatewayLogger.Error("MessageBus DLL initialization failed");
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_GATEWAY);
	gatewayLogger.Info("Service started | v" + "1.00" + " | built " + (string)__DATETIME__);

	gatewayLogger.Info("Entering main loop");

	while (!IsStopped()) {
		SEMessageBus::WaitForMessage(MB_CHANNEL_EVENTS_OUT, EVENT_POLL_INTERVAL * 1000);

		consumeAndForwardTradingEvents();
		consumeAndForwardServiceEvents();
		processAckResponses();
		logDiagnostics();
	}

	SEMessageBus::UnregisterService(MB_SERVICE_GATEWAY);
	SEMessageBus::Shutdown();
	gatewayLogger.Info("Service stopped");

	if (SELogger::GetGlobalEntryCount() > 0) {
		string logEntries[];
		SELogger::GetGlobalEntries(logEntries);

		SRReportOfLogs logExporter;
		logExporter.Initialize(GetLogsPath("HorizonGateway"));
		logExporter.Export("Logs", logEntries);

		SELogger::ClearGlobalEntries();
	}

	return 0;
}
