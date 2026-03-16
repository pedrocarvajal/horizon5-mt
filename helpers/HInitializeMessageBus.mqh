#ifndef __H_INITIALIZE_MESSAGE_BUS_MQH__
#define __H_INITIALIZE_MESSAGE_BUS_MQH__

#include "../services/SEMessageBus/SEMessageBus.mqh"
#include "../services/SEMessageBus/SEMessageBusChannels.mqh"
#include "../services/SELogger/SELogger.mqh"

bool InitializeMessageBus() {
	if (SEMessageBus::IsActive()) {
		return true;
	}

	SELogger messageBusLogger("MessageBus");

	if (!SEMessageBus::Initialize()) {
		messageBusLogger.Error("DLL failed to initialize");
		return false;
	}

	string requiredServices[] = { MB_SERVICE_API, MB_SERVICE_PERSISTENCE };

	if (!SEMessageBus::AreServicesReady(requiredServices, 2)) {
		messageBusLogger.Error("Services not running");
		return false;
	}

	SEMessageBus::Activate();
	messageBusLogger.Info("Enabled, all services running");
	return true;
}

#endif
