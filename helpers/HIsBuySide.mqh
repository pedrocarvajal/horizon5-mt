#ifndef __H_IS_BUY_SIDE_MQH__
#define __H_IS_BUY_SIDE_MQH__

bool IsBuySide(ENUM_ORDER_TYPE side) {
	return side == ORDER_TYPE_BUY ||
	       side == ORDER_TYPE_BUY_STOP ||
	       side == ORDER_TYPE_BUY_LIMIT ||
	       side == ORDER_TYPE_BUY_STOP_LIMIT;
}

#endif
