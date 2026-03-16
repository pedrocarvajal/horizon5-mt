#ifndef __H_HANDLE_GET_KLINES_MQH__
#define __H_HANDLE_GET_KLINES_MQH__

void HandleGetKlines(SHorizonEvent &event, HorizonAPI &api, SELogger &eventLogger) {
	eventLogger.Info(StringFormat("Event received | %s | id=%s", event.key, event.id));
	if (event.symbol == "" || event.timeframe == "" || event.fromDate == "" || event.toDate == "") {
		AckServiceEventError(event, api, eventLogger, "symbol, timeframe, from_date and to_date are required");
		return;
	}

	ENUM_TIMEFRAMES period = MapTimeframe(event.timeframe);
	if (period == PERIOD_CURRENT) {
		AckServiceEventError(event, api, eventLogger, "Invalid or unsupported timeframe");
		return;
	}

	datetime fromTime = StringToTime(event.fromDate);
	datetime toTime = StringToTime(event.toDate);

	MqlRates rates[];
	int copied = CopyRates(event.symbol, period, fromTime, toTime, rates);

	if (copied <= 0) {
		AckServiceEventError(event, api, eventLogger, "No kline data available for the requested range");
		return;
	}

	string csvFileName = event.symbol + "_" + event.timeframe + ".csv";
	string csvPath = StringFormat("/Klines/%lld/%s", AccountInfoInteger(ACCOUNT_LOGIN), csvFileName);

	int fileHandle = FileOpen(csvPath, FILE_WRITE | FILE_ANSI | FILE_COMMON, ",", CP_UTF8);

	if (fileHandle == INVALID_HANDLE) {
		AckServiceEventError(event, api, eventLogger, "Failed to create CSV file");
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
		AckServiceEventError(event, api, eventLogger, "Failed to read CSV file for upload");
		return;
	}

	FileReadArray(readHandle, fileData);
	FileClose(readHandle);

	string uploadedFileName = api.UploadMedia(csvFileName, fileData);

	FileDelete(csvPath, FILE_COMMON);

	if (uploadedFileName == "") {
		AckServiceEventError(event, api, eventLogger, "Failed to upload CSV file");
		return;
	}

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);
	ackBody.setProperty("file_name", uploadedFileName);
	ackBody.setProperty("rows", copied);
	eventLogger.Info(StringFormat("Event ack | %s | rows=%d | id=%s", event.key, copied, event.id));
	api.AckEvent(event.id, ackBody);
}

#endif
