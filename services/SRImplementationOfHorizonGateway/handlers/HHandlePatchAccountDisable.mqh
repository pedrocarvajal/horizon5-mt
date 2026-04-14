#ifndef __H_HANDLE_GATEWAY_PATCH_ACCOUNT_DISABLE_MQH__
#define __H_HANDLE_GATEWAY_PATCH_ACCOUNT_DISABLE_MQH__

void HandlePatchAccountDisable(SGatewayEvent &event, HorizonGateway &gateway, SELogger &eventLogger, STradingStatus &status) {
	status.isPaused = true;
	status.reason = TRADING_PAUSE_REASON_HORIZON_API_REQUEST;

	JSON::Object ackBody;
	ackBody.setProperty("status", "disabled");
	gateway.AckEvent(event.id, ackBody);

	eventLogger.Warning(LOG_CODE_REMOTE_HTTP_ERROR, "Account disabled via Gateway event");
}

#endif
