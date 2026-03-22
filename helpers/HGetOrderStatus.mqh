#ifndef __H_GET_ORDER_STATUS_MQH__
#define __H_GET_ORDER_STATUS_MQH__

#include "../enums/EOrderStatuses.mqh"

string GetOrderStatus(ENUM_ORDER_STATUSES status) {
	if (status == ORDER_STATUS_PENDING) {
		return "pending";
	}

	if (status == ORDER_STATUS_OPEN) {
		return "open";
	}

	if (status == ORDER_STATUS_CLOSING) {
		return "closing";
	}

	if (status == ORDER_STATUS_CLOSED) {
		return "closed";
	}

	if (status == ORDER_STATUS_CANCELLED) {
		return "cancelled";
	}

	return "unknown";
}

#endif
