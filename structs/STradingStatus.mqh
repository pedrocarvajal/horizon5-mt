#ifndef __S_TRADING_STATUS_MQH__
#define __S_TRADING_STATUS_MQH__

#include "../enums/ETradingPauseReason.mqh"

struct STradingStatus {
	bool isPaused;
	ENUM_TRADING_PAUSE_REASON reason;

	STradingStatus() {
		isPaused = false;
		reason = TRADING_PAUSE_REASON_NONE;
	}
};

#endif
