#ifndef __H_HANDLE_DELETE_ORDER_MQH__
#define __H_HANDLE_DELETE_ORDER_MQH__

void SEGateway::handleDeleteOrder(SGatewayEvent &event) {
	if (event.orderId == "") {
		ackWithError(event.id, "Order ID is required");
		return;
	}

	EOrder *order = NULL;
	SEOrderBook *orderBook = NULL;

	for (int i = 0; i < ArraySize(strategies); i++) {
		SEOrderBook *book = strategies[i].GetOrderBook();
		int idx = book.FindOrderIndexById(event.orderId);

		if (idx != -1) {
			order = book.GetOrderAtIndex(idx);
			orderBook = book;
			break;
		}
	}

	if (order == NULL) {
		ackWithError(event.id, StringFormat("Order %s not found", event.orderId));
		return;
	}

	bool isValid = order.GetStatus() == ORDER_STATUS_OPEN
		       || order.GetStatus() == ORDER_STATUS_PENDING;

	if (!isValid) {
		ackWithError(event.id, StringFormat(
			"Order status is %s, expected open or pending",
			GetOrderStatus(order.GetStatus())
		));
		return;
	}

	if (order.GetStatus() == ORDER_STATUS_PENDING) {
		int pendingIndex = tracker.FindOpenIndex(order.GetId());

		if (pendingIndex != -1) {
			tracker.ConsumeOpen(pendingIndex);
		}
	}

	tracker.TrackClose(order.GetId(), event.id);
	orderBook.CloseOrder(order);

	logger.Info(
		LOG_CODE_REMOTE_HTTP_ERROR,
		StringFormat(
			"delete order queued | event_id=%s symbol=%s order_id=%s",
			event.id,
			order.GetSymbol(),
			event.orderId
	));
}

#endif
