#ifndef __I_EVENT_HANDLER_MQH__
#define __I_EVENT_HANDLER_MQH__

#include "../integrations/HorizonAPI/structs/SHorizonEvent.mqh"

interface IEventHandler {
	void Handle(SHorizonEvent &event);
};

#endif
