#property service
#property copyright "Horizon5"
#property version   "1.20"
#property strict

#define SERVICE_VERSION "1.2.0"

#include "enums/EDebugLevel.mqh"
#include "services/SELogger/SELogger.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "services/SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"
#include "helpers/HMapTimeframe.mqh"
#include "integrations/HorizonAPI/HorizonAPI.mqh"
#include "integrations/HorizonAPI/structs/SEventResponse.mqh"

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

void ackError(SHorizonEvent &event, string message) {
	hlogger.Warning(StringFormat("Event ack | %s | error=%s | id=%s", event.key, message, event.id));
	JSON::Object ackBody;
	SEventResponse response;
	response.Error(message);
	response.ApplyTo(ackBody);
	horizonAPI.AckEvent(event.id, ackBody);
}

void handleGetAccountInfo(SHorizonEvent &event) {
	hlogger.Info(StringFormat("Event received | %s | id=%s", event.key, event.id));
	double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN) > 0
		? NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2)
		: 0.0;

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);
	ackBody.setProperty("balance", ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2));
	ackBody.setProperty("equity", ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2));
	ackBody.setProperty("margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN), 13, 2));
	ackBody.setProperty("free_margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 13, 2));
	ackBody.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
	ackBody.setProperty("margin_level", ClampNumeric(marginLevel, 8, 2));
	ackBody.setProperty("currency", AccountInfoString(ACCOUNT_CURRENCY));
	ackBody.setProperty("leverage", (int)AccountInfoInteger(ACCOUNT_LEVERAGE));

	hlogger.Info(StringFormat("Event ack | %s | id=%s", event.key, event.id));
	horizonAPI.AckEvent(event.id, ackBody);
}

void handleGetTicker(SHorizonEvent &event) {
	hlogger.Info(StringFormat("Event received | %s | id=%s", event.key, event.id));
	if (event.symbol == "") {
		ackError(event, "No symbols provided");
		return;
	}

	string symbols[];
	int symbolCount = StringSplit(event.symbol, ',', symbols);

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);

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

	hlogger.Info(StringFormat("Event ack | %s | id=%s", event.key, event.id));
	horizonAPI.AckEvent(event.id, ackBody);
}

void handleGetKlines(SHorizonEvent &event) {
	hlogger.Info(StringFormat("Event received | %s | id=%s", event.key, event.id));
	if (event.symbol == "" || event.timeframe == "" || event.fromDate == "" || event.toDate == "") {
		ackError(event, "symbol, timeframe, from_date and to_date are required");
		return;
	}

	ENUM_TIMEFRAMES period = MapTimeframe(event.timeframe);
	if (period == PERIOD_CURRENT) {
		ackError(event, "Invalid or unsupported timeframe");
		return;
	}

	datetime fromTime = StringToTime(event.fromDate);
	datetime toTime = StringToTime(event.toDate);

	MqlRates rates[];
	int copied = CopyRates(event.symbol, period, fromTime, toTime, rates);

	if (copied <= 0) {
		ackError(event, "No kline data available for the requested range");
		return;
	}

	string csvFileName = event.symbol + "_" + event.timeframe + ".csv";
	string csvPath = StringFormat("/Klines/%lld/%s", AccountInfoInteger(ACCOUNT_LOGIN), csvFileName);

	int fileHandle = FileOpen(csvPath, FILE_WRITE | FILE_ANSI | FILE_COMMON, ",", CP_UTF8);

	if (fileHandle == INVALID_HANDLE) {
		ackError(event, "Failed to create CSV file");
		return;
	}

	int digits = (int)SymbolInfoInteger(event.symbol, SYMBOL_DIGITS);

	FileWrite(fileHandle, "Time", "Open", "High", "Low", "Close", "TickVolume", "Spread", "RealVolume");

	for (int i = 0; i < copied; i++) {
		FileWrite(fileHandle,
			TimeToString(rates[i].time, TIME_DATE | TIME_SECONDS),
			DoubleToString(rates[i].open, digits),
			DoubleToString(rates[i].high, digits),
			DoubleToString(rates[i].low, digits),
			DoubleToString(rates[i].close, digits),
			IntegerToString(rates[i].tick_volume),
			IntegerToString(rates[i].spread),
			IntegerToString(rates[i].real_volume)
		);
	}

	FileClose(fileHandle);

	char fileData[];
	int readHandle = FileOpen(csvPath, FILE_READ | FILE_BIN | FILE_COMMON);

	if (readHandle == INVALID_HANDLE) {
		FileDelete(csvPath, FILE_COMMON);
		ackError(event, "Failed to read CSV file for upload");
		return;
	}

	FileReadArray(readHandle, fileData);
	FileClose(readHandle);

	string uploadedFileName = horizonAPI.UploadMedia(csvFileName, fileData);

	FileDelete(csvPath, FILE_COMMON);

	if (uploadedFileName == "") {
		ackError(event, "Failed to upload CSV file");
		return;
	}

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);
	ackBody.setProperty("file_name", uploadedFileName);
	ackBody.setProperty("rows", copied);
	hlogger.Info(StringFormat("Event ack | %s | rows=%d | id=%s", event.key, copied, event.id));
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

	SHorizonEvent klineEvents[];
	int klineCount = horizonAPI.ConsumeEvents("get.klines", "", klineEvents, MaxEventsPerPoll);
	for (int i = 0; i < klineCount; i++) {
		handleGetKlines(klineEvents[i]);
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

	hlogger.Info("Service started | v" + SERVICE_VERSION + " | built " + (string)__DATETIME__);

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
