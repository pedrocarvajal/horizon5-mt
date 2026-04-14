#ifndef __H_IS_VALID_MONITOR_SEED_TIMESTAMP_MQH__
#define __H_IS_VALID_MONITOR_SEED_TIMESTAMP_MQH__

#include "../../../constants/COTimestamp.mqh"

bool IsValidMonitorSeedTimestamp(long timestamp) {
	return timestamp >= VALID_TIMESTAMP_MIN && timestamp <= VALID_TIMESTAMP_MAX;
}

#endif
