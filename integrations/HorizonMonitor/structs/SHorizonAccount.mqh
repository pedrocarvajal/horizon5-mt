#ifndef __S_MONITOR_HORIZON_ACCOUNT_MQH__
#define __S_MONITOR_HORIZON_ACCOUNT_MQH__

struct SHorizonAccount {
	string status;

	SHorizonAccount() {
		status = "";
	}

	bool IsActive() {
		return status == "active";
	}
};

#endif
