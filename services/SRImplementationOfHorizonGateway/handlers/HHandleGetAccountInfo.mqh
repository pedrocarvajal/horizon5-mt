#ifndef __H_HANDLE_GATEWAY_GET_ACCOUNT_INFO_MQH__
#define __H_HANDLE_GATEWAY_GET_ACCOUNT_INFO_MQH__

#include "../../../entities/EAccount.mqh"

void HandleGetAccountInfo(SGatewayEvent &event, HorizonGateway &gateway, SELogger &eventLogger) {
	eventLogger.Info(StringFormat("Event received | %s | id=%s", event.key, event.id));
	EAccount account;

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);
	ackBody.setProperty("balance", ClampNumeric(account.GetBalance(), 13, 2));
	ackBody.setProperty("equity", ClampNumeric(account.GetEquity(), 13, 2));
	ackBody.setProperty("margin", ClampNumeric(account.GetMargin(), 13, 2));
	ackBody.setProperty("free_margin", ClampNumeric(account.GetFreeMargin(), 13, 2));
	ackBody.setProperty("profit", ClampNumeric(account.GetProfit(), 13, 2));
	ackBody.setProperty("margin_level", ClampNumeric(account.GetSafeMarginLevel(), 8, 2));
	ackBody.setProperty("currency", account.GetCurrency());
	ackBody.setProperty("leverage", account.GetLeverage());

	eventLogger.Info(StringFormat("Event ack | %s | id=%s", event.key, event.id));
	gateway.AckEvent(event.id, ackBody);
}

#endif
