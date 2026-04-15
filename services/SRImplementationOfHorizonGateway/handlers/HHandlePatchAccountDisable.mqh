#ifndef __H_HANDLE_GATEWAY_PATCH_ACCOUNT_DISABLE_MQH__
#define __H_HANDLE_GATEWAY_PATCH_ACCOUNT_DISABLE_MQH__

void SRImplementationOfHorizonGateway::handlePatchAccountDisable(SGatewayEvent &event) {
	tradingStatus.isPaused = true;
	tradingStatus.reason = TRADING_PAUSE_REASON_HORIZON_API_REQUEST;

	JSON::Object ackBody;
	ackBody.setProperty("status", "disabled");
	gateway.AckEvent(event.id, ackBody);

	logger.Warning(
		LOG_CODE_REMOTE_HTTP_ERROR,
		"Account disabled via Gateway event"
	);
}

#endif
