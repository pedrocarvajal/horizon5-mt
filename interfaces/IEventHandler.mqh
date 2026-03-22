#ifndef __I_EVENT_HANDLER_MQH__
#define __I_EVENT_HANDLER_MQH__

#include "../integrations/HorizonGateway/structs/SGatewayEvent.mqh"

interface IEventHandler {
	void Handle(SGatewayEvent &event);
};

#endif
