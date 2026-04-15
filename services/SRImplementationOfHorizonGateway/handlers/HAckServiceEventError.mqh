#ifndef __H_ACK_GATEWAY_EVENT_ERROR_MQH__
#define __H_ACK_GATEWAY_EVENT_ERROR_MQH__

void SRImplementationOfHorizonGateway::ackServiceEventError(SGatewayEvent &event, string message) {
	logger.Warning(
		LOG_CODE_REMOTE_HTTP_ERROR,
		StringFormat(
			"Event ack | %s | error=%s | id=%s",
			event.key,
			message,
			event.id
	));
	JSON::Object ackBody;
	SEventResponse response;
	response.Error(message);
	response.ApplyTo(ackBody);
	gateway.AckEvent(event.id, ackBody);
}

#endif
