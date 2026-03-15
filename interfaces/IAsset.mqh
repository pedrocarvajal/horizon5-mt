#ifndef __I_ASSET_MQH__
#define __I_ASSET_MQH__

class EOrder;

interface IAsset {
	int OnInit();
	int OnTesterInit();

	void OnTimer();
	void OnTick();
	void OnStartMinute();
	void OnStartHour();
	void OnStartDay();

	void OnOpenOrder(EOrder &order);
	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason);
	void OnEnd();
	void OnDeinit();
};

#endif
