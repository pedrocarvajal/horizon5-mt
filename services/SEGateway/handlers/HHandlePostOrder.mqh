#ifndef __H_HANDLE_POST_ORDER_MQH__
#define __H_HANDLE_POST_ORDER_MQH__

#include "../helpers/HParseOrderType.mqh"
#include "../helpers/HBuildNotificationPayload.mqh"

#include "../PendingEntryTracker.mqh"

#include "../../../constants/CONotificationType.mqh"

#include "../../../integrations/HorizonGateway/structs/SGatewayEvent.mqh"

extern SRImplementationOfHorizonGateway horizonGateway;
extern STradingStatus tradingStatus;

void HandlePostOrder(
	SGatewayEvent &event,
	string assetSymbol,
	SEStrategy *&strategies[],
	PendingEntryTracker &tracker,
	SELogger &eventLogger
) {
	if (event.symbol != "" && event.symbol != assetSymbol) {
		return;
	}

	ENUM_ORDER_TYPE side = ParseOrderType(event.type);

	if (side == INVALID_ORDER_TYPE) {
		AckWithError(event.id, StringFormat("Unknown order type: %s", event.type), eventLogger);
		return;
	}

	if (event.volume <= 0) {
		AckWithError(event.id, "Volume must be greater than 0", eventLogger);
		return;
	}

	if (tradingStatus.isPaused) {
		AckWithError(event.id, StringFormat("Trading is paused (reason: %d)", tradingStatus.reason), eventLogger);
		return;
	}

	if (event.strategyId == "") {
		AckWithError(event.id, "Strategy id is required", eventLogger);
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
		AckWithError(event.id, StringFormat("Strategy %s not found in asset %s", event.strategyId, assetSymbol), eventLogger);
		return;
	}

	bool isMarket = IsMarketOrderType(side);
	double openAtPrice = event.price;

	if (openAtPrice <= 0) {
		if (!isMarket) {
			AckWithError(event.id, StringFormat("Price is required for %s orders", event.type), eventLogger);
			return;
		}

		openAtPrice = IsBuySide(side)
			? SymbolInfoDouble(assetSymbol, SYMBOL_ASK)
			: SymbolInfoDouble(assetSymbol, SYMBOL_BID);
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
		AckWithError(event.id, "PlaceOrder returned NULL", eventLogger);
		return;
	}

	if (isMarket) {
		tracker.TrackOpen(order.GetId(), event.id);

		eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat(
			"post order queued | event_id=%s event_type=%s symbol=%s order_id=%s lots=%.2f price=%.5f",
			event.id,
			event.type,
			assetSymbol,
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

		eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat(
			"event acked | event_type=%s event_id=%s symbol=%s order_id=%s lots=%.2f price=%.5f status=pending",
			event.type,
			event.id,
			assetSymbol,
			order.GetId(),
			event.volume,
			openAtPrice
		));

		if (horizonGateway.IsEnabled()) {
			JSON::Object *notificationPayload = new JSON::Object();
			BuildOrderPayloadCommon(order, notificationPayload);
			horizonGateway.PublishNotification(NOTIFICATION_TYPE_ORDER_PLACED, event.strategyId, "", assetSymbol, notificationPayload);
		}
	}
}

#endif
