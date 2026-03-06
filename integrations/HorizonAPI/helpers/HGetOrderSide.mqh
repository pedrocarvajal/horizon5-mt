#ifndef __H_GET_ORDER_SIDE_MQH__
#define __H_GET_ORDER_SIDE_MQH__

string GetOrderSide(int side) {
	if (side == ORDER_TYPE_BUY) {
		return "buy";
	}

	if (side == ORDER_TYPE_SELL) {
		return "sell";
	}

	return "unknown";
}

#endif
