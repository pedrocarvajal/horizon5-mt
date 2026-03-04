#property service
#property copyright "Horizon5"
#property version   "1.01"
#property strict

#include "enums/EDebugLevel.mqh"
#include "services/SELogger/SELogger.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "services/SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"
#include "integrations/HorizonAPI/HorizonAPI.mqh"

input group "General Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "HorizonAPI Integration";
input bool EnableHorizonAPI = true; // [1] > Enable HorizonAPI integration
input string HorizonAPIUrl = ""; // [1] > HorizonAPI base URL
input string HorizonAPIKey = ""; // [1] > HorizonAPI key (required)
input int HorizonAPIEventPollInterval = 3; // [1] > Event poll interval in seconds
input int MaxEventsPerPoll = 10; // [1] > Max events per ConsumeEvents call

SEDateTime dtime;
SELogger hlogger("HorizonAPI");
HorizonAPI horizonAPI;

void handleGetAccountInfo(SHorizonEvent &event) {
	double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN) > 0
		? NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2)
		: 0.0;

	JSON::Object ackBody;
	ackBody.setProperty("balance", ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2));
	ackBody.setProperty("equity", ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2));
	ackBody.setProperty("margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN), 13, 2));
	ackBody.setProperty("free_margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 13, 2));
	ackBody.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
	ackBody.setProperty("margin_level", ClampNumeric(marginLevel, 8, 2));
	ackBody.setProperty("currency", AccountInfoString(ACCOUNT_CURRENCY));
	ackBody.setProperty("leverage", (int)AccountInfoInteger(ACCOUNT_LEVERAGE));

	horizonAPI.AckEvent(event.id, ackBody);
}

void handleGetTicker(SHorizonEvent &event) {
	if (event.symbol == "") {
		JSON::Object ackBody;
		ackBody.setProperty("status", "error");
		ackBody.setProperty("error_code", "missing_symbols");
		ackBody.setProperty("error_message", "No symbols provided");
		horizonAPI.AckEvent(event.id, ackBody);
		return;
	}

	string symbols[];
	int symbolCount = StringSplit(event.symbol, ',', symbols);

	JSON::Object ackBody;

	for (int i = 0; i < symbolCount; i++) {
		string symbol = symbols[i];
		StringTrimRight(symbol);
		StringTrimLeft(symbol);

		if (symbol == "" || !SymbolSelect(symbol, true)) {
			continue;
		}

		ackBody.setProperty(symbol + "_bid", ClampNumeric(SymbolInfoDouble(symbol, SYMBOL_BID), 10, 5));
		ackBody.setProperty(symbol + "_ask", ClampNumeric(SymbolInfoDouble(symbol, SYMBOL_ASK), 10, 5));
	}

	horizonAPI.AckEvent(event.id, ackBody);
}

void processEvents() {
	SHorizonEvent accountInfoEvents[];
	int accountInfoCount = horizonAPI.ConsumeEvents("get.account.info", "", accountInfoEvents, MaxEventsPerPoll);
	for (int i = 0; i < accountInfoCount; i++) {
		handleGetAccountInfo(accountInfoEvents[i]);
	}

	SHorizonEvent tickerEvents[];
	int tickerCount = horizonAPI.ConsumeEvents("get.ticker", "", tickerEvents, MaxEventsPerPoll);
	for (int i = 0; i < tickerCount; i++) {
		handleGetTicker(tickerEvents[i]);
	}
}

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);

	while (!IsStopped() && !TerminalInfoInteger(TERMINAL_CONNECTED)) {
		Sleep(1000);
	}

	if (!horizonAPI.Initialize(HorizonAPIUrl, HorizonAPIKey, EnableHorizonAPI && IsLiveTrading())) {
		hlogger.Warning("HorizonAPI initialization failed — service idle");
		return 0;
	}

	if (horizonAPI.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(horizonAPI));
		horizonAPI.UpsertAccount();
		horizonAPI.StoreSystemHeartbeat(HEARTBEAT_INIT);
	}

	hlogger.Info("Service started | built " + (string)__DATETIME__);

	while (!IsStopped()) {
		processEvents();
		Sleep(HorizonAPIEventPollInterval * 1000);
	}

	hlogger.Info("Service stopped");

	horizonAPI.StoreSystemHeartbeat(HEARTBEAT_DEINIT);

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
