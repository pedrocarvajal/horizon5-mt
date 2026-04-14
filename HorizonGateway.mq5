#property service
#property copyright "Horizon5"
#property version   "0.13"
#property strict

#include "constants/COHorizonGateway.mqh"
#include "constants/CODiagnostic.mqh"
#include "constants/COMessageBus.mqh"

#include "enums/EDebugLevel.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"

#include "services/SELogger/SELogger.mqh"
#include "services/SEMessageBus/SEMessageBus.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

#include "integrations/HorizonGateway/HorizonGateway.mqh"

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
	int tradingCount = horizonGateway.ConsumeEvents(tradingKeys, "", tradingEvents, MAX_EVENTS_PER_POLL, "", false);

	if (tradingCount > 0) {
		gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, StringFormat(
			"events consumed | event_type=trading count=%d",
			tradingCount
		));
	}

	for (int i = 0; i < tradingCount; i++) {
		JSON::Object eventPayload;
		tradingEvents[i].ToJson(eventPayload);
		bool sent = SEMessageBus::Send(MB_CHANNEL_EVENTS_IN, tradingEvents[i].key, eventPayload);
		gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, StringFormat(
			"event forwarded | event_type=%s event_id=%s strategy_id=%s symbol=%s sent=%s",
			tradingEvents[i].key,
			tradingEvents[i].id,
			tradingEvents[i].strategyId,
			tradingEvents[i].symbol,
			sent ? "ok" : "failed"
		));
	}
}

void consumeAndForwardServiceEvents() {
	string serviceKeys = joinKeys(EVENT_KEYS_SERVICE);

	SGatewayEvent serviceEvents[];
	int serviceCount = horizonGateway.ConsumeEvents(serviceKeys, "", serviceEvents, MAX_EVENTS_PER_POLL, "", false);

	for (int i = 0; i < serviceCount; i++) {
		JSON::Object eventPayload;
		serviceEvents[i].ToJson(eventPayload);
		SEMessageBus::Send(MB_CHANNEL_EVENTS_SERVICE, serviceEvents[i].key, eventPayload);
		gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, StringFormat(
			"event forwarded | event_type=%s event_id=%s channel=service",
			serviceEvents[i].key,
			serviceEvents[i].id
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
		if (ackMessages[i].messageType != MB_TYPE_ACK_EVENT) {
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

		gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, StringFormat(
			"event acked | event_id=%s",
			eventId
		));
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

	gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, StringFormat(
		"queue diagnostics | events_in=%d events_out=%d events_service=%d",
		pendingEventsIn,
		pendingEventsOut,
		pendingEventsService
	));
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);
	SELogger::SetLogSystem(LOG_SYSTEM_HORIZON5_GATEWAY_SERVICE);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!horizonGateway.Initialize(HorizonGatewayUrl, HorizonGatewayEmail, HorizonGatewayPassword, IsLiveTrading())) {
		gatewayLogger.Warning(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, "service idle | reason='gateway initialization failed'");
		return 0;
	}

	if (horizonGateway.IsEnabled()) {
		if (!horizonGateway.UpsertAccount()) {
			gatewayLogger.Error(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, "service idle | reason='account registration failed'");
			return 0;
		}
	}

	if (!SEMessageBus::Initialize()) {
		gatewayLogger.Error(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, "service idle | reason='message bus DLL initialization failed'");
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_GATEWAY);
	gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE,
		"service started | system=HorizonGateway version=0.13 built='2026-04-14 19:59:38'");

	gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, "main loop entered | system=HorizonGateway");

	while (!IsStopped()) {
		SEMessageBus::WaitForMessage(MB_CHANNEL_EVENTS_OUT, EVENT_POLL_INTERVAL_SECONDS * 1000);

		consumeAndForwardTradingEvents();
		consumeAndForwardServiceEvents();
		processAckResponses();
		logDiagnostics();
	}

	SEMessageBus::UnregisterService(MB_SERVICE_GATEWAY);
	SEMessageBus::Shutdown();
	gatewayLogger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, "service stopped | system=HorizonGateway");

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
