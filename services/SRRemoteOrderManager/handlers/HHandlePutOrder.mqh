#ifndef __H_HANDLE_PUT_ORDER_MQH__
#define __H_HANDLE_PUT_ORDER_MQH__

#include "../helpers/HSanitizePrice.mqh"
#include "../../../integrations/HorizonGateway/structs/SGatewayEvent.mqh"

extern SRImplementationOfHorizonGateway horizonGateway;

void HandlePutOrder(
	SGatewayEvent &event,
	SEStrategy *&strategies[],
	SELogger &eventLogger
) {
	if (event.stopLoss <= 0 && event.takeProfit <= 0) {
		AckWithError(event.id, "At least one of stop_loss or take_profit must be provided", eventLogger);
		return;
	}

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

	if (order.GetStatus() != ORDER_STATUS_OPEN) {
		AckWithError(event.id, StringFormat(
			"Order status is %s, expected open",
			GetOrderStatus(order.GetStatus())
			), eventLogger);
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
		AckWithError(event.id, StringFormat(
			"Failed to modify SL to %.5f / TP to %.5f", event.stopLoss, event.takeProfit
			), eventLogger);
		return;
	}

	JSON::Object ackBody;
	ackBody.setProperty("status", "updated");
	ackBody.setProperty("ticket", (long)order.GetPositionId());
	ackBody.setProperty("stop_loss", SanitizePrice(order.GetStopLossPrice()));
	ackBody.setProperty("take_profit", SanitizePrice(order.GetTakeProfitPrice()));
	horizonGateway.AckEvent(event.id, ackBody);

	eventLogger.Info(StringFormat(
		"put.order acked | order %s | sl=%.5f tp=%.5f",
		event.orderId, order.GetStopLossPrice(), order.GetTakeProfitPrice()
	));
}

#endif
