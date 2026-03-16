#ifndef __H_HANDLE_PATCH_ACCOUNT_ENABLE_MQH__
#define __H_HANDLE_PATCH_ACCOUNT_ENABLE_MQH__

void HandlePatchAccountEnable(SHorizonEvent &event, HorizonAPI &api, SELogger &eventLogger, STradingStatus &status) {
	status.isPaused = false;
	status.reason = TRADING_PAUSE_REASON_NONE;

	JSON::Object ackBody;
	ackBody.setProperty("status", "enabled");
	api.AckEvent(event.id, ackBody);

	eventLogger.Info("Account enabled via API event");
}

#endif
