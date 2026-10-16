#ifndef __E_ACCOUNT_MQH__
#define __E_ACCOUNT_MQH__

class EAccount {
public:
	long GetNumber() {
		return AccountInfoInteger(ACCOUNT_LOGIN);
	}

	double GetBalance() {
		return AccountInfoDouble(ACCOUNT_BALANCE);
	}

	double GetFreeMargin() {
		return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
	}

	bool IsTradeAllowed() {
		return (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
	}

	long GetMaxOrders() {
		return AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
	}
};

#endif
