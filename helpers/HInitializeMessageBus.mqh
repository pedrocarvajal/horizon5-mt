#ifndef __H_INITIALIZE_MESSAGE_BUS_MQH__
#define __H_INITIALIZE_MESSAGE_BUS_MQH__

#include "../services/SEMessageBus/SEMessageBus.mqh"
#include "../services/SEMessageBus/SEMessageBusChannels.mqh"
#include "../services/SELogger/SELogger.mqh"

bool InitializeMessageBus(string &requiredServices[], int serviceCount) {
	if (SEMessageBus::IsActive()) {
		return true;
	}

	SELogger messageBusLogger("MessageBus");

	if (!SEMessageBus::Initialize()) {
		messageBusLogger.Error("DLL failed to initialize");
		return false;
	}

	for (int i = 0; i < serviceCount; i++) {
		bool running = SEMessageBus::IsServiceRunning(requiredServices[i]);
		messageBusLogger.Info(StringFormat(
			"Service check | %s | running: %s",
			requiredServices[i],
			running ? "yes" : "no"
		));
	}

	if (!SEMessageBus::AreServicesReady(requiredServices, serviceCount)) {
		messageBusLogger.Error("Services not running");
		return false;
	}

	SEMessageBus::Activate();
	messageBusLogger.Info("Enabled, all services running");
	return true;
}

#endif
