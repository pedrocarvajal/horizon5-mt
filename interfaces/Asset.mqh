#ifndef __ASSET_MQH__
#define __ASSET_MQH__

#include "../services/Logger/Logger.mqh"
#include "../services/Order/Order.mqh"
#include "../interfaces/Strategy.mqh"


class IAsset {
public:
	string name;
	string symbol;
	IStrategy *asset_strategies[];

	Logger logger;

private:

public:
	virtual int onInit() {
		return INIT_SUCCEEDED;
	};

	virtual void onDeinit() {
	};

	virtual int onTesterInit() {
		return INIT_SUCCEEDED;
	};

	virtual void onTick() {
	};

	virtual void onStartMinute() {
	};

	virtual void onStartHour() {
	};

	virtual void onStartDay() {
	};

	virtual void onStartWeek() {
	};

	virtual void onStartMonth() {
	};

	virtual void onEndWeek() {
	};

	virtual void onOpenOrder(Order &order) {
	};

	virtual void onCloseOrder(Order &order, ENUM_DEAL_REASON reason) {
	};

	virtual void SetSymbol(string asset_symbol) {
		symbol = asset_symbol;
	};

	virtual void SetName(string asset_name) {
		name = asset_name;
	};

	virtual void SetNewStrategy(IStrategy *strategy) {
		ArrayResize(asset_strategies, ArraySize(asset_strategies) + 1);
		asset_strategies[ArraySize(asset_strategies) - 1] = strategy;
	};
};

#endif
