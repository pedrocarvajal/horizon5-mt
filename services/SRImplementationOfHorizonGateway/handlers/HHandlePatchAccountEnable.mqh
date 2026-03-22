#ifndef __H_HANDLE_GATEWAY_PATCH_ACCOUNT_ENABLE_MQH__
#define __H_HANDLE_GATEWAY_PATCH_ACCOUNT_ENABLE_MQH__

void HandlePatchAccountEnable(SGatewayEvent &event, HorizonGateway &gateway, SELogger &eventLogger, STradingStatus &status) {
	status.isPaused = false;
	status.reason = TRADING_PAUSE_REASON_NONE;

	JSON::Object ackBody;
	ackBody.setProperty("status", "enabled");
	gateway.AckEvent(event.id, ackBody);

	eventLogger.Info("Account enabled via Gateway event");
}

#endif
