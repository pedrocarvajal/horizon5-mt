#ifndef __H_PARSE_ORDER_TYPE_MQH__
#define __H_PARSE_ORDER_TYPE_MQH__

const int INVALID_ORDER_TYPE = -1;

ENUM_ORDER_TYPE ParseOrderType(const string &typeName) {
	if (typeName == "buy") {
		return ORDER_TYPE_BUY;
	}

	if (typeName == "sell") {
		return ORDER_TYPE_SELL;
	}

	if (typeName == "buy_stop") {
		return ORDER_TYPE_BUY_STOP;
	}

	if (typeName == "sell_stop") {
		return ORDER_TYPE_SELL_STOP;
	}

	if (typeName == "buy_limit") {
		return ORDER_TYPE_BUY_LIMIT;
	}

	if (typeName == "sell_limit") {
		return ORDER_TYPE_SELL_LIMIT;
	}

	return (ENUM_ORDER_TYPE)INVALID_ORDER_TYPE;
}

bool IsBuySide(ENUM_ORDER_TYPE side) {
	return side == ORDER_TYPE_BUY || side == ORDER_TYPE_BUY_STOP || side == ORDER_TYPE_BUY_LIMIT;
}

bool IsMarketOrderType(ENUM_ORDER_TYPE side) {
	return side == ORDER_TYPE_BUY || side == ORDER_TYPE_SELL;
}

#endif
