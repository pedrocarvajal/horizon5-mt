#ifndef __H_DELETE_OLD_ORDERS_MQH__
#define __H_DELETE_OLD_ORDERS_MQH__

#include "../services/SELogger/SELogger.mqh"
#include "../entities/EOrder.mqh"

extern EOrder orders[];

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
		if (orders[i].GetStatus() == ORDER_STATUS_CLOSED || orders[i].GetStatus() == ORDER_STATUS_CANCELLED) {
			orders[i].OnDeinit();
			closedCount++;
		} else {
			ArrayResize(tempOrders, activeCount + 1);
			tempOrders[activeCount] = orders[i];
			activeCount++;
		}
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
