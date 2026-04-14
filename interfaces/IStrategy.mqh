#ifndef __I_STRATEGY_MQH__
#define __I_STRATEGY_MQH__

class EOrder;

interface IStrategy {
	int OnInit();
	int OnTesterInit();

	void OnTimer();
	void OnTick();
	void OnStartMinute();
	void OnStartHour();
	void OnStartDay();

	void OnOpenOrder(EOrder &order);
	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason);
	void OnCancelOrder(EOrder &order);
	void OnPendingOrderPlaced(EOrder &order);
	void OnOrderUpdated(EOrder &order);
	void OnEnd();
	void OnDeinit();

	void SetWeight(double allocatedWeight);
	void SetMagicNumber(ulong magic);

	bool IsTradable();

	string GetPrefix();
	ulong GetMagicNumber();
};

#endif
