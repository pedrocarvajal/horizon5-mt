#ifndef __H_HANDLE_PUT_ORDER_MQH__
#define __H_HANDLE_PUT_ORDER_MQH__

void SEGateway::handlePutOrder(SGatewayEvent &event) {
	if (event.stopLoss <= 0 && event.takeProfit <= 0) {
		ackWithError(event.id, "At least one of stop_loss or take_profit must be provided");
		return;
	}

	if (event.orderId == "") {
		ackWithError(event.id, "Order ID is required");
		return;
	}

	EOrder *order = NULL;
	SEOrderBook *orderBook = NULL;
	string targetStrategyUuid = "";

	for (int i = 0; i < ArraySize(strategies); i++) {
		SEOrderBook *book = strategies[i].GetOrderBook();
		int idx = book.FindOrderIndexById(event.orderId);

		if (idx != -1) {
			order = book.GetOrderAtIndex(idx);
			orderBook = book;
			targetStrategyUuid = strategies[i].GetStrategyUuid();
			break;
		}
	}

	if (order == NULL) {
		ackWithError(event.id, StringFormat("Order %s not found", event.orderId));
		return;
	}

	if (order.GetStatus() != ORDER_STATUS_OPEN && order.GetStatus() != ORDER_STATUS_PENDING) {
		ackWithError(event.id, StringFormat(
			"Order status is %s, expected open or pending",
			GetOrderStatus(order.GetStatus())
		));
		return;
	}

	bool modified = false;

	if (event.stopLoss > 0 && event.takeProfit > 0) {
		modified = orderBook.ModifyStopLossAndTakeProfit(order, event.stopLoss, event.takeProfit);
	} else if (event.stopLoss > 0) {
		modified = orderBook.ModifyStopLoss(order, event.stopLoss);
	} else if (event.takeProfit > 0) {
		modified = orderBook.ModifyTakeProfit(order, event.takeProfit);
	}

	if (!modified) {
		ackWithError(event.id, StringFormat(
			"Failed to modify SL to %.5f / TP to %.5f", event.stopLoss, event.takeProfit
		));
		return;
	}

	JSON::Object ackBody;
	ackBody.setProperty("status", "updated");
	ackBody.setProperty("ticket", (long)order.GetPositionId());
	ackBody.setProperty("stop_loss", SanitizePrice(order.GetStopLossPrice()));
	ackBody.setProperty("take_profit", SanitizePrice(order.GetTakeProfitPrice()));
	horizonGateway.AckEvent(event.id, ackBody);

	logger.Info(
		LOG_CODE_REMOTE_HTTP_ERROR,
		StringFormat(
			"event acked | event_type=put.order event_id=%s symbol=%s order_id=%s sl=%.5f tp=%.5f",
			event.id,
			order.GetSymbol(),
			event.orderId,
			order.GetStopLossPrice(),
			order.GetTakeProfitPrice()
	));

	if (horizonGateway.IsEnabled()) {
		JSON::Object *notificationPayload = new JSON::Object();
		BuildOrderModifiedPayload(order, notificationPayload);
		horizonGateway.PublishNotification(NOTIFICATION_TYPE_ORDER_MODIFIED, targetStrategyUuid, "", order.GetSymbol(), notificationPayload);
	}
}

#endif
