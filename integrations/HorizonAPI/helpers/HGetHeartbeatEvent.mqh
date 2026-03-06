#ifndef __H_GET_HEARTBEAT_EVENT_MQH__
#define __H_GET_HEARTBEAT_EVENT_MQH__

#include "../enums/EHeartbeatEvent.mqh"

string GetHeartbeatEvent(ENUM_HEARTBEAT_EVENT event) {
	if (event == HEARTBEAT_INIT) {
		return "on_init";
	}

	if (event == HEARTBEAT_DEINIT) {
		return "on_deinit";
	}

	if (event == HEARTBEAT_RUNNING) {
		return "on_running";
	}

	if (event == HEARTBEAT_ERROR) {
		return "on_error";
	}

	return "unknown";
}

#endif
