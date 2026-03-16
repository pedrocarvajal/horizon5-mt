#property service
#property copyright "Horizon5"
#property version   "2.04"
#property strict

#include "enums/EDebugLevel.mqh"

#include "helpers/HIsLiveTrading.mqh"
#include "helpers/HGetLogsPath.mqh"

#include "services/SELogger/SELogger.mqh"
#include "services/SEMessageBus/SEMessageBus.mqh"
#include "services/SEMessageBus/SEMessageBusChannels.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"

#include "integrations/HorizonAPI/HorizonAPI.mqh"

#define SERVICE_VERSION "2.0.0"
#define MESSAGE_TYPE_HTTP_POST "http_post"
#define MESSAGE_TYPE_ACK_EVENT "ack_event"
#define API_ORDER_PATH_PREFIX  "api/v1/order/"

#define EVENT_KEYS_TRADING "post.order,delete.order,put.order,get.orders"
#define EVENT_KEYS_SERVICE "get.account.info,get.ticker,get.klines,patch.account.disable,patch.account.enable"

SEDateTime dtime;
SELogger hlogger("HorizonAPI");
HorizonAPI horizonAPI;

input group "General Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "HorizonAPI Integration";
input string HorizonAPIUrl = ""; // [1] > HorizonAPI base URL
input string HorizonAPIEmail = ""; // [1] > HorizonAPI email (required)
input string HorizonAPIPassword = ""; // [1] > HorizonAPI password (required)

input group "Service Settings";
input int PollIntervalMs = 100; // [1] > Connector poll interval in milliseconds
input int HorizonAPIEventPollInterval = 3; // [1] > Event poll interval in seconds
input int MaxEventsPerPoll = 10; // [1] > Max events per ConsumeEvents call

datetime lastEventPollTime = 0;

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

	horizonAPI.PostDirect(path, *bodyObject);

	SEMessageBus::Ack(MB_CHANNEL_CONNECTOR, message.sequence);
}

bool shouldPollEvents() {
	datetime now = TimeCurrent();

	if ((now - lastEventPollTime) < HorizonAPIEventPollInterval) {
		return false;
	}

	lastEventPollTime = now;
	return true;
}

void consumeAndForwardTradingEvents() {
	string tradingKeys = EVENT_KEYS_TRADING;

	SHorizonEvent tradingEvents[];
	int tradingCount = horizonAPI.ConsumeEvents(tradingKeys, "", tradingEvents, MaxEventsPerPoll);

	for (int i = 0; i < tradingCount; i++) {
		JSON::Object eventPayload;
		tradingEvents[i].ToJson(eventPayload);
		SEMessageBus::Send(MB_CHANNEL_EVENTS_IN, tradingEvents[i].key, eventPayload);
		hlogger.Info(StringFormat(
			"Event forwarded to EA | %s | strategy=%d | id=%s",
			tradingEvents[i].key, tradingEvents[i].strategyId, tradingEvents[i].id
		));
	}
}

void consumeAndForwardServiceEvents() {
	string serviceKeys = EVENT_KEYS_SERVICE;

	SHorizonEvent serviceEvents[];
	int serviceCount = horizonAPI.ConsumeEvents(serviceKeys, "", serviceEvents, MaxEventsPerPoll);

	for (int i = 0; i < serviceCount; i++) {
		JSON::Object eventPayload;
		serviceEvents[i].ToJson(eventPayload);
		SEMessageBus::Send(MB_CHANNEL_EVENTS_SERVICE, serviceEvents[i].key, eventPayload);
		hlogger.Info(StringFormat(
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
		horizonAPI.AckEvent(eventId, responseBody);

		hlogger.Info(StringFormat("Ack forwarded to API | event=%s", eventId));
		SEMessageBus::Ack(MB_CHANNEL_EVENTS_OUT, ackMessages[i].sequence);
	}
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!horizonAPI.Initialize(HorizonAPIUrl, HorizonAPIEmail, HorizonAPIPassword, IsLiveTrading())) {
		hlogger.Warning("HorizonAPI initialization failed, service idle");
		return 0;
	}

	if (horizonAPI.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(horizonAPI));
		horizonAPI.UpsertAccount();
		horizonAPI.StoreSystemHeartbeat(HEARTBEAT_INIT);
	}

	if (!SEMessageBus::Initialize()) {
		hlogger.Error("MessageBus DLL initialization failed");
		return 0;
	}

	SEMessageBus::RegisterService(MB_SERVICE_API);
	hlogger.Info("Service started | v" + SERVICE_VERSION + " | built " + (string)__DATETIME__);

	while (!IsStopped()) {
		SEMessageBus::WaitForMessage(MB_CHANNEL_CONNECTOR, PollIntervalMs);

		processConnectorMessages();

		if (shouldPollEvents()) {
			consumeAndForwardTradingEvents();
			consumeAndForwardServiceEvents();
		}

		processAckResponses();
	}

	SELogger::SetRemoteLogger(NULL);
	SEMessageBus::UnregisterService(MB_SERVICE_API);
	SEMessageBus::Shutdown();
	hlogger.Info("Service stopped");

	if (SELogger::GetGlobalEntryCount() > 0) {
		string logEntries[];
		SELogger::GetGlobalEntries(logEntries);

		SRReportOfLogs logExporter;
		logExporter.Initialize(GetLogsPath("HorizonAPI"));
		logExporter.Export("Logs", logEntries);

		SELogger::ClearGlobalEntries();
	}

	return 0;
}
