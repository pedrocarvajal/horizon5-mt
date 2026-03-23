#ifndef __H_GET_SNAPSHOT_EVENT_MQH__
#define __H_GET_SNAPSHOT_EVENT_MQH__

#include "../enums/ESnapshotEvent.mqh"

string GetSnapshotEvent(ENUM_SNAPSHOT_EVENT event) {
	if (event == SNAPSHOT_ON_INIT) {
		return "on_init";
	}

	if (event == SNAPSHOT_ON_HOUR) {
		return "on_hour";
	}

	if (event == SNAPSHOT_ON_END_DAY) {
		return "on_end_day";
	}

	return "unknown";
}

#endif
