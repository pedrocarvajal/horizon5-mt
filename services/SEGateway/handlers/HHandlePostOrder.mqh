#ifndef __H_HANDLE_POST_ORDER_MQH__
#define __H_HANDLE_POST_ORDER_MQH__

void SEGateway::handlePostOrder(SGatewayEvent &event) {
	if (event.symbol != "" && event.symbol != symbol) {
		return;
	}

	ENUM_ORDER_TYPE side = ParseOrderType(event.type);

	if (side == INVALID_ORDER_TYPE) {
		ackWithError(event.id, StringFormat("Unknown order type: %s", event.type));
		return;
	}

	if (event.volume <= 0) {
		ackWithError(event.id, "Volume must be greater than 0");
		return;
	}

	if (tradingStatus.isPaused) {
		ackWithError(event.id, StringFormat("Trading is paused (reason: %d)", tradingStatus.reason));
		return;
	}

	if (event.strategyId == "") {
		ackWithError(event.id, "Strategy id is required");
		return;
	}

	SEOrderBook *targetOrderBook = NULL;

	for (int i = 0; i < ArraySize(strategies); i++) {
		if (strategies[i].GetStrategyUuid() == event.strategyId) {
			targetOrderBook = strategies[i].GetOrderBook();
			break;
		}
	}

	if (targetOrderBook == NULL) {
		ackWithError(event.id, StringFormat("Strategy %s not found in asset %s", event.strategyId, symbol));
		return;
	}

	bool isMarket = IsMarketOrderType(side);
	double openAtPrice = event.price;

	if (openAtPrice <= 0) {
		if (!isMarket) {
			ackWithError(event.id, StringFormat("Price is required for %s orders", event.type));
			return;
		}

		openAtPrice = IsBuySide(side)
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);
	}

	EOrder *order = targetOrderBook.PlaceOrder(
		side,
		openAtPrice,
		event.volume,
		isMarket,
		event.takeProfit,
		event.stopLoss
	);

	if (order == NULL) {
		ackWithError(event.id, "PlaceOrder returned NULL");
		return;
	}

	if (isMarket) {
		tracker.TrackOpen(order.GetId(), event.id);

		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"post order queued | event_id=%s event_type=%s symbol=%s order_id=%s lots=%.2f price=%.5f",
				event.id,
				event.type,
				symbol,
				order.GetId(),
				event.volume,
				openAtPrice
		));
	} else {
		JSON::Object ackBody;
		ackBody.setProperty("status", "pending");
		ackBody.setProperty("ticket", (long)order.GetOrderId());
		ackBody.setProperty("open_price", openAtPrice);
		horizonGateway.AckEvent(event.id, ackBody);

		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"event acked | event_type=%s event_id=%s symbol=%s order_id=%s lots=%.2f price=%.5f status=pending",
				event.type,
				event.id,
				symbol,
				order.GetId(),
				event.volume,
				openAtPrice
		));

		if (horizonGateway.IsEnabled()) {
			JSON::Object *notificationPayload = new JSON::Object();
			BuildOrderPayloadCommon(order, notificationPayload);
			horizonGateway.PublishNotification(NOTIFICATION_TYPE_ORDER_PLACED, event.strategyId, "", symbol, notificationPayload);
		}
	}
}

#endif
