#ifndef __H_GET_SYSTEM_NAME_MQH__
#define __H_GET_SYSTEM_NAME_MQH__

#include "../enums/ESystemName.mqh"

string GetSystemName(ENUM_SYSTEM_NAME system) {
	if (system == SYSTEM_HORIZON5) {
		return "horizon5";
	}

	if (system == SYSTEM_GATEWAY_SERVICE) {
		return "horizon5-gateway-service";
	}

	if (system == SYSTEM_PERSISTENCE_SERVICE) {
		return "horizon5-persistence-service";
	}

	if (system == SYSTEM_MONITOR_SERVICE) {
		return "horizon5-monitor-service";
	}

	return "unknown";
}

#endif
