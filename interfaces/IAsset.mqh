#ifndef __I_ASSET_MQH__
#define __I_ASSET_MQH__

class EOrder;

interface IAsset {
	int OnInit();
	int OnTesterInit();

	void OnTick();
	void OnStartMinute();
	void OnStartHour();
	void OnStartDay();
	void OnStartWeek();
	void OnStartMonth();

	void OnOpenOrder(EOrder &order);
	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason);
	void OnEndWeek();
	void OnDeinit();

	void SetSymbol(string assetSymbol);
	void SetName(string assetName);
	void SetMagicNumber(ulong magic);
	void SetBalance(double assetBalance);

	int GetStrategyCount();
	double GetQualityProduct();
};

#endif
