#ifndef __H_HANDLE_GET_ACCOUNT_INFO_MQH__
#define __H_HANDLE_GET_ACCOUNT_INFO_MQH__

void HandleGetAccountInfo(SHorizonEvent &event, HorizonAPI &api, SELogger &eventLogger) {
	eventLogger.Info(StringFormat("Event received | %s | id=%s", event.key, event.id));
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

	eventLogger.Info(StringFormat("Event ack | %s | id=%s", event.key, event.id));
	api.AckEvent(event.id, ackBody);
}

#endif
