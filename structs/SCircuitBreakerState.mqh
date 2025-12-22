#ifndef __SCIRCUIT_BREAKER_STATE_MQH__
#define __SCIRCUIT_BREAKER_STATE_MQH__

struct SCircuitBreakerState {
	ENUM_CIRCUIT_BREAKER_STATE state;
	int failure_count;
	datetime last_failure_time;
	int failure_threshold;
	int cooldown_seconds;

	SCircuitBreakerState() {
		state = CIRCUIT_BREAKER_CLOSED;
		failure_count = 0;
		last_failure_time = 0;
		failure_threshold = 3;
		cooldown_seconds = 900;
	}
};

#endif
