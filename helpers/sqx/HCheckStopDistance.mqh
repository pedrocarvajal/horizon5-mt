#ifndef __SQX_CHECK_STOP_DISTANCE_MQH__
#define __SQX_CHECK_STOP_DISTANCE_MQH__

bool CheckStopDistance(double stopPrice, string symbolName, ENUM_ORDER_TYPE orderType) {
	int stopLevel = (int)SymbolInfoInteger(symbolName, SYMBOL_TRADE_STOPS_LEVEL);
	double point = SymbolInfoDouble(symbolName, SYMBOL_POINT);
	double minDistance = point * stopLevel;

	if (minDistance <= 0) {
		return true;
	}

	MqlTick lastTick;

	if (!SymbolInfoTick(symbolName, lastTick)) {
		return false;
	}

	if (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_LIMIT) {
		return stopPrice >= lastTick.ask + minDistance;
	}

	if (orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_BUY_LIMIT) {
		return stopPrice <= lastTick.bid - minDistance;
	}

	return true;
}

#endif
