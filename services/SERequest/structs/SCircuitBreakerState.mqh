#ifndef __S_CIRCUIT_BREAKER_STATE_MQH__
#define __S_CIRCUIT_BREAKER_STATE_MQH__

#include "../enums/ECircuitBreakerState.mqh"

struct SCircuitBreakerState {
	ENUM_CIRCUIT_BREAKER_STATE state;
	int failureCount;
	datetime lastFailureTime;
	int failureThreshold;
	int cooldownSeconds;

	SCircuitBreakerState() {
		state = CIRCUIT_BREAKER_CLOSED;
		failureCount = 0;
		lastFailureTime = 0;
		failureThreshold = 3;
		cooldownSeconds = 900;
	}
};

#endif
