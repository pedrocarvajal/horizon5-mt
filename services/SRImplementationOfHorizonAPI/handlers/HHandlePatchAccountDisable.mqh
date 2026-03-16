#ifndef __H_HANDLE_PATCH_ACCOUNT_DISABLE_MQH__
#define __H_HANDLE_PATCH_ACCOUNT_DISABLE_MQH__

void HandlePatchAccountDisable(SHorizonEvent &event, HorizonAPI &api, SELogger &eventLogger, STradingStatus &status) {
	status.isPaused = true;
	status.reason = TRADING_PAUSE_REASON_HORIZON_API_REQUEST;

	JSON::Object ackBody;
	ackBody.setProperty("status", "disabled");
	api.AckEvent(event.id, ackBody);

	eventLogger.Warning("Account disabled via API event");
}

#endif
