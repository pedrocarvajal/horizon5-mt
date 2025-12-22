#ifndef __CLEANUP_CLOSED_ORDERS_MQH__
#define __CLEANUP_CLOSED_ORDERS_MQH__

#define MAX_CLOSED_ORDERS_HISTORY 21

void deleteOldOrders() {
	Logger log;
	log.SetPrefix("DeleteOldOrders");

	int original_size = ArraySize(orders);

	if (original_size == 0)
		return;

	Order temp_orders[];
	int active_count = 0;
	int closed_count = 0;

	for (int i = 0; i < original_size; i++) {
		if (orders[i].status == ORDER_STATUS_CLOSED || orders[i].status == ORDER_STATUS_CANCELLED) {
			// Move to closed orders history before cleanup
			ArrayResize(closed_orders, ArraySize(closed_orders) + 1);
			closed_orders[ArraySize(closed_orders) - 1] = orders[i];

			orders[i].onDeinit();
			closed_count++;
		} else {
			ArrayResize(temp_orders, active_count + 1);
			temp_orders[active_count] = orders[i];
			active_count++;
		}
	}

	// Limit closed orders history to prevent excessive memory usage
	int closed_size = ArraySize(closed_orders);
	if (closed_size > MAX_CLOSED_ORDERS_HISTORY) {
		int excess = closed_size - MAX_CLOSED_ORDERS_HISTORY;
		Order temp_closed[];

		ArrayResize(temp_closed, MAX_CLOSED_ORDERS_HISTORY);
		for (int i = 0; i < MAX_CLOSED_ORDERS_HISTORY; i++)
			temp_closed[i] = closed_orders[excess + i];

		// Clean up the excess orders
		for (int i = 0; i < excess; i++)
			closed_orders[i].onDeinit();

		ArrayResize(closed_orders, MAX_CLOSED_ORDERS_HISTORY);
		for (int i = 0; i < MAX_CLOSED_ORDERS_HISTORY; i++)
			closed_orders[i] = temp_closed[i];

		ArrayResize(temp_closed, 0);
		ArrayFree(temp_closed);

		log.info("Trimmed closed orders history: removed " + IntegerToString(excess) + " oldest orders");
	}

	ArrayResize(orders, active_count);
	for (int i = 0; i < active_count; i++)
		orders[i] = temp_orders[i];

	ArrayResize(temp_orders, 0);
	ArrayFree(temp_orders);

	if (closed_count > 0)
		log.info("Cleanup completed: Removed " + IntegerToString(closed_count) + " closed orders. Active orders: " + IntegerToString(active_count) + " (was " + IntegerToString(original_size) + ")");
}

#endif
