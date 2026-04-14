#ifndef __H_FILTER_ORDERS_MQH__
#define __H_FILTER_ORDERS_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../constants/COOrder.mqh"

void FilterOrders(
	EOrder &sourceOrders[],
	EOrder &resultOrders[],
	ENUM_ORDER_TYPE side,
	ENUM_ORDER_STATUSES status,
	ENUM_ORDER_STATUSES fallbackStatus,
	ENUM_ORDER_STATUSES secondaryFallbackStatus = ORDER_STATUS_ANY
) {
	int sourceCount = ArraySize(sourceOrders);
	ArrayResize(resultOrders, 0, sourceCount);

	int resultCount = 0;

	for (int i = 0; i < sourceCount; i++) {
		if (side != ORDER_TYPE_ANY && sourceOrders[i].GetSide() != side) {
			continue;
		}

		ENUM_ORDER_STATUSES currentStatus = sourceOrders[i].GetStatus();
		bool isStatusMatch;

		if (status != ORDER_STATUS_ANY) {
			isStatusMatch = (currentStatus == status);
		} else {
			isStatusMatch = (currentStatus == fallbackStatus) ||
					(secondaryFallbackStatus != ORDER_STATUS_ANY &&
					 currentStatus == secondaryFallbackStatus);
		}

		if (!isStatusMatch) {
			continue;
		}

		resultCount++;
		ArrayResize(resultOrders, resultCount);
		resultOrders[resultCount - 1] = sourceOrders[i];
	}
}

#endif
