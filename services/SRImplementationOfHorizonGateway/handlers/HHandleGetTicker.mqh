#ifndef __H_HANDLE_GATEWAY_GET_TICKER_MQH__
#define __H_HANDLE_GATEWAY_GET_TICKER_MQH__

void SRImplementationOfHorizonGateway::handleGetTicker(SGatewayEvent &event) {
	logger.Info(
		LOG_CODE_REMOTE_HTTP_ERROR,
		StringFormat(
			"Event received | %s | id=%s",
			event.key,
			event.id
	));
	if (event.symbol == "") {
		ackServiceEventError(event, "No symbols provided");
		return;
	}

	string symbols[];
	int symbolCount = StringSplit(event.symbol, ',', symbols);

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);

	for (int i = 0; i < symbolCount; i++) {
		string tickerSymbol = symbols[i];
		StringTrimRight(tickerSymbol);
		StringTrimLeft(tickerSymbol);

		if (tickerSymbol == "" || !SymbolSelect(tickerSymbol, true)) {
			continue;
		}

		ackBody.setProperty(tickerSymbol + "_bid", ClampNumeric(SymbolInfoDouble(tickerSymbol, SYMBOL_BID), 10, 5));
		ackBody.setProperty(tickerSymbol + "_ask", ClampNumeric(SymbolInfoDouble(tickerSymbol, SYMBOL_ASK), 10, 5));
	}

	logger.Info(
		LOG_CODE_REMOTE_HTTP_ERROR,
		StringFormat(
			"Event ack | %s | id=%s",
			event.key,
			event.id
	));
	gateway.AckEvent(event.id, ackBody);
}

#endif
