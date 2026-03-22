#ifndef __H_ACK_GATEWAY_EVENT_ERROR_MQH__
#define __H_ACK_GATEWAY_EVENT_ERROR_MQH__

void AckServiceEventError(SGatewayEvent &event, HorizonGateway &gateway, SELogger &eventLogger, string message) {
	eventLogger.Warning(StringFormat("Event ack | %s | error=%s | id=%s", event.key, message, event.id));
	JSON::Object ackBody;
	SEventResponse response;
	response.Error(message);
	response.ApplyTo(ackBody);
	gateway.AckEvent(event.id, ackBody);
}

#endif
