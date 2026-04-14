#ifndef __H_HANDLE_GATEWAY_GET_ACCOUNT_INFO_MQH__
#define __H_HANDLE_GATEWAY_GET_ACCOUNT_INFO_MQH__

#include "../../../entities/EAccount.mqh"

void HandleGetAccountInfo(SGatewayEvent &event, HorizonGateway &gateway, SELogger &eventLogger) {
	eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat("Event received | %s | id=%s", event.key, event.id));
	EAccount localAccount;

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);
	ackBody.setProperty("balance", ClampNumeric(localAccount.GetBalance(), 13, 2));
	ackBody.setProperty("equity", ClampNumeric(localAccount.GetEquity(), 13, 2));
	ackBody.setProperty("margin", ClampNumeric(localAccount.GetMargin(), 13, 2));
	ackBody.setProperty("free_margin", ClampNumeric(localAccount.GetFreeMargin(), 13, 2));
	ackBody.setProperty("profit", ClampNumeric(localAccount.GetProfit(), 13, 2));
	ackBody.setProperty("margin_level", ClampNumeric(localAccount.GetSafeMarginLevel(), 8, 2));
	ackBody.setProperty("currency", localAccount.GetCurrency());
	ackBody.setProperty("leverage", localAccount.GetLeverage());

	eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat("Event ack | %s | id=%s", event.key, event.id));
	gateway.AckEvent(event.id, ackBody);
}

#endif
