#ifndef __H_INITIALIZE_MESSAGE_BUS_MQH__
#define __H_INITIALIZE_MESSAGE_BUS_MQH__

#include "../services/SEMessageBus/SEMessageBus.mqh"
#include "../services/SELogger/SELogger.mqh"

#include "../constants/COMessageBus.mqh"

bool InitializeMessageBus(string &requiredServices[], int serviceCount) {
	if (SEMessageBus::IsActive()) {
		return true;
	}

	SELogger messageBusLogger("MessageBus");

	if (!SEMessageBus::Initialize()) {
		messageBusLogger.Error(
			LOG_CODE_FRAMEWORK_INIT_FAILED,
			"DLL failed to initialize"
		);
		return false;
	}

	for (int i = 0; i < serviceCount; i++) {
		bool running = SEMessageBus::IsServiceRunning(requiredServices[i]);
		messageBusLogger.Info(
			LOG_CODE_FRAMEWORK_INIT_FAILED,
			StringFormat(
				"Service check | %s | running: %s",
				requiredServices[i],
				running ? "yes" : "no"
		));
	}

	if (!SEMessageBus::AreServicesReady(requiredServices, serviceCount)) {
		messageBusLogger.Error(
			LOG_CODE_FRAMEWORK_INIT_FAILED,
			"Services not running"
		);
		return false;
	}

	SEMessageBus::Activate();
	messageBusLogger.Info(
		LOG_CODE_FRAMEWORK_INIT_FAILED,
		"Enabled, all services running"
	);
	return true;
}

#endif
