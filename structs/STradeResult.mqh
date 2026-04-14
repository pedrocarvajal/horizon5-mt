#ifndef __S_TRADE_RESULT_MQH__
#define __S_TRADE_RESULT_MQH__

#include "../enums/ETradeSeverity.mqh"

struct STradeResult {
	uint retcode;
	ENUM_TRADE_SEVERITY severity;
	ulong dealId;
	ulong orderId;
	ulong positionId;
	double price;
	double volume;
};

#endif
