#ifndef __H_IS_EXPIRED_ORDER_MQH__
#define __H_IS_EXPIRED_ORDER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../constants/COOrder.mqh"

bool IsExpiredOrder(EOrder &order) {
	if (order.GetStatus() != ORDER_STATUS_CLOSED && order.GetStatus() != ORDER_STATUS_CANCELLED) {
		return false;
	}

	datetime closeTimestamp = order.GetCloseAt().timestamp;

	if (closeTimestamp == 0) {
		return false;
	}

	return (TimeCurrent() - closeTimestamp) > EXPIRED_ORDER_THRESHOLD_SECONDS;
}

#endif
