#ifndef __H_DELETE_OLD_ORDERS_MQH__
#define __H_DELETE_OLD_ORDERS_MQH__

#include "../services/SELogger/SELogger.mqh"
#include "../entities/EOrder.mqh"

extern EOrder orders[];
extern EOrder closedOrders[];

#define MAX_CLOSED_ORDERS_HISTORY 21

void deleteOldOrders() {
	SELogger log;
	log.SetPrefix("DeleteOldOrders");

	int originalSize = ArraySize(orders);

	if (originalSize == 0)
		return;

	EOrder tempOrders[];
	int activeCount = 0;
	int closedCount = 0;

	for (int i = 0; i < originalSize; i++) {
		if (orders[i].status == ORDER_STATUS_CLOSED || orders[i].status == ORDER_STATUS_CANCELLED) {
			ArrayResize(closedOrders, ArraySize(closedOrders) + 1);
			closedOrders[ArraySize(closedOrders) - 1] = orders[i];

			orders[i].OnDeinit();
			closedCount++;
		} else {
			ArrayResize(tempOrders, activeCount + 1);
			tempOrders[activeCount] = orders[i];
			activeCount++;
		}
	}

	int closedSize = ArraySize(closedOrders);
	if (closedSize > MAX_CLOSED_ORDERS_HISTORY) {
		int excess = closedSize - MAX_CLOSED_ORDERS_HISTORY;
		EOrder tempClosed[];

		ArrayResize(tempClosed, MAX_CLOSED_ORDERS_HISTORY);
		for (int i = 0; i < MAX_CLOSED_ORDERS_HISTORY; i++)
			tempClosed[i] = closedOrders[excess + i];

		for (int i = 0; i < excess; i++)
			closedOrders[i].OnDeinit();

		ArrayResize(closedOrders, MAX_CLOSED_ORDERS_HISTORY);
		for (int i = 0; i < MAX_CLOSED_ORDERS_HISTORY; i++)
			closedOrders[i] = tempClosed[i];

		ArrayResize(tempClosed, 0);
		ArrayFree(tempClosed);

		log.info("Trimmed closed orders history: removed " + IntegerToString(excess) + " oldest orders");
	}

	ArrayResize(orders, activeCount);
	for (int i = 0; i < activeCount; i++)
		orders[i] = tempOrders[i];

	ArrayResize(tempOrders, 0);
	ArrayFree(tempOrders);

	if (closedCount > 0)
		log.info("Cleanup completed: Removed " + IntegerToString(closedCount) + " closed orders. Active orders: " + IntegerToString(activeCount) + " (was " + IntegerToString(originalSize) + ")");
}

#endif
