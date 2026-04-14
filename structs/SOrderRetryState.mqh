#ifndef __S_ORDER_RETRY_STATE_MQH__
#define __S_ORDER_RETRY_STATE_MQH__

struct SOrderRetryState {
	bool retryable;
	int count;
	datetime after;

	SOrderRetryState() {
		retryable = false;
		count = 0;
		after = 0;
	}

	void Reset() {
		count = 0;
		after = 0;
	}
};

#endif
