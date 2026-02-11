#ifndef __I_STRATEGY_MQH__
#define __I_STRATEGY_MQH__

class EOrder;
class SEAsset;

interface IStrategy {
	int OnInit();
	int OnTesterInit();

	void OnTick();
	void OnStartMinute();
	void OnStartHour();
	void OnStartDay();

	void OnOpenOrder(EOrder &order);
	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason);
	void OnDeinit();

	void SetAsset(SEAsset *assetReference);
	void SetWeight(double allocatedWeight);
	void SetMagicNumber(ulong magic);

	string GetPrefix();
	ulong GetMagicNumber();
};

#endif
