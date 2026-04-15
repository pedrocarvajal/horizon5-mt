#ifndef __H_ACK_WITH_ERROR_MQH__
#define __H_ACK_WITH_ERROR_MQH__

void SEGateway::ackWithError(const string eventId, const string message) {
	logger.Warning(
		LOG_CODE_REMOTE_REQUEST_INVALID,
		StringFormat(
			"event handler failed | event_id=%s reason='%s'",
			eventId,
			message
	));

	JSON::Object ackBody;
	ackBody.setProperty("status", "error");
	ackBody.setProperty("message", message);
	horizonGateway.AckEvent(eventId, ackBody);
}

#endif
