#ifndef __S_HORIZON_ACCOUNT_MQH__
#define __S_HORIZON_ACCOUNT_MQH__

struct SHorizonAccount {
	string status;
	string broker;
	string server;
	string currency;
	int leverage;
	double balance;
	double equity;
	double margin;
	double freeMargin;
	double profit;
	double marginLevel;

	SHorizonAccount() {
		status = "";
		broker = "";
		server = "";
		currency = "";
		leverage = 0;
		balance = 0;
		equity = 0;
		margin = 0;
		freeMargin = 0;
		profit = 0;
		marginLevel = 0;
	}

	bool IsActive() {
		return status == "active";
	}
};

#endif
