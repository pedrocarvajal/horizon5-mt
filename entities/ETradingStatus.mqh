#ifndef __E_TRADING_STATUS_MQH__
#define __E_TRADING_STATUS_MQH__

class ETradingStatus {
private:
	bool isPaused;

public:
	ETradingStatus() {
		isPaused = false;
	}

	bool IsPaused() {
		return isPaused;
	}

	void Pause() {
		isPaused = true;
	}

	void Resume() {
		isPaused = false;
	}
};

#endif
