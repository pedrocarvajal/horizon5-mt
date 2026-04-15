#ifndef __H_HANDLE_GATEWAY_PATCH_ACCOUNT_ENABLE_MQH__
#define __H_HANDLE_GATEWAY_PATCH_ACCOUNT_ENABLE_MQH__

void SRImplementationOfHorizonGateway::handlePatchAccountEnable(SGatewayEvent &event) {
	tradingStatus.isPaused = false;
	tradingStatus.reason = TRADING_PAUSE_REASON_NONE;

	JSON::Object ackBody;
	ackBody.setProperty("status", "enabled");
	gateway.AckEvent(event.id, ackBody);

	logger.Info(
		LOG_CODE_REMOTE_HTTP_ERROR,
		"Account enabled via Gateway event"
	);
}

#endif
