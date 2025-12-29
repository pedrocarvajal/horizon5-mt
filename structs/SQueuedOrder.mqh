#ifndef __S_QUEUED_ORDER_MQH__
#define __S_QUEUED_ORDER_MQH__

#include "../enums/EQueueActions.mqh"

class EOrder;

struct SQueuedOrder {
	ENUM_QUEUE_ACTIONS action;
	EOrder *order;
	ulong positionId;
};

#endif
