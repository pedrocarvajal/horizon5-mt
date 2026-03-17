#ifndef __H_GET_ORDER_SIDE_MQH__
#define __H_GET_ORDER_SIDE_MQH__

string GetOrderSide(int side) {
	if (side == ORDER_TYPE_BUY || side == ORDER_TYPE_BUY_LIMIT || side == ORDER_TYPE_BUY_STOP || side == ORDER_TYPE_BUY_STOP_LIMIT) {
		return "buy";
	}

	if (side == ORDER_TYPE_SELL || side == ORDER_TYPE_SELL_LIMIT || side == ORDER_TYPE_SELL_STOP || side == ORDER_TYPE_SELL_STOP_LIMIT) {
		return "sell";
	}

	return "unknown";
}

#endif
