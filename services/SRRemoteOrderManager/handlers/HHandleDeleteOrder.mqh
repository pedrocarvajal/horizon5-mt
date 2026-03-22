#ifndef __H_HANDLE_DELETE_ORDER_MQH__
#define __H_HANDLE_DELETE_ORDER_MQH__

#include "../PendingEntryTracker.mqh"
#include "../../../integrations/HorizonGateway/structs/SGatewayEvent.mqh"

void HandleDeleteOrder(
	SGatewayEvent &event,
	SEStrategy *&strategies[],
	PendingEntryTracker &tracker,
	SELogger &eventLogger
) {
	if (event.orderId == "") {
		AckWithError(event.id, "Order ID is required", eventLogger);
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
		AckWithError(event.id, StringFormat("Order %s not found", event.orderId), eventLogger);
		return;
	}

	bool isValid = order.GetStatus() == ORDER_STATUS_OPEN
		       || order.GetStatus() == ORDER_STATUS_PENDING;

	if (!isValid) {
		AckWithError(event.id, StringFormat(
			"Order status is %s, expected open or pending",
			GetOrderStatus(order.GetStatus())
			), eventLogger);
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

	eventLogger.Info(StringFormat(
		"delete.order queued | order %s | awaiting broker confirmation",
		event.orderId
	));
}

#endif
