#ifndef __H_HANDLE_GET_ORDERS_MQH__
#define __H_HANDLE_GET_ORDERS_MQH__

#include "../helpers/HSanitizePrice.mqh"
#include "../../../integrations/HorizonGateway/structs/SGatewayEvent.mqh"
#include "../../../helpers/HGetOrderSide.mqh"
#include "../../../helpers/HGetOrderStatus.mqh"

extern SRImplementationOfHorizonGateway horizonGateway;

JSON::Object *SerializeActiveOrder(EOrder *order, SEOrderBook *orderBook) {
	JSON::Object *orderObject = new JSON::Object();
	orderObject.setProperty("id", order.GetId());
	orderObject.setProperty("ticket", (long)order.GetOrderId());
	orderObject.setProperty("position_id", (long)order.GetPositionId());
	orderObject.setProperty("symbol", order.GetSymbol());
	orderObject.setProperty("side", GetOrderSide(order.GetSide()));
	orderObject.setProperty("status", GetOrderStatus(order.GetStatus()));
	orderObject.setProperty("volume", order.GetVolume());
	orderObject.setProperty("open_price", order.GetOpenPrice());
	orderObject.setProperty("stop_loss", SanitizePrice(order.GetStopLossPrice()));
	orderObject.setProperty("take_profit", SanitizePrice(order.GetTakeProfitPrice()));
	orderObject.setProperty("floating_pnl", orderBook.GetFloatingProfitAndLoss(order));
	return orderObject;
}

bool MatchesOrderFilters(EOrder *order, SGatewayEvent &event) {
	if (event.symbol != "" && order.GetSymbol() != event.symbol) {
		return false;
	}

	if (event.side != "" && GetOrderSide(order.GetSide()) != event.side) {
		return false;
	}

	if (event.status != "" && GetOrderStatus(order.GetStatus()) != event.status) {
		return false;
	}

	return true;
}

bool IsDuplicateId(const string &addedIds[], const string orderId) {
	for (int i = 0; i < ArraySize(addedIds); i++) {
		if (addedIds[i] == orderId) {
			return true;
		}
	}

	return false;
}

void HandleGetOrders(
	SGatewayEvent &event,
	SEStrategy *&strategies[],
	SELogger &eventLogger
) {
	JSON::Array *ordersArray = new JSON::Array();
	int matchCount = 0;
	string addedIds[];

	for (int s = 0; s < ArraySize(strategies); s++) {
		SEOrderBook *orderBook = strategies[s].GetOrderBook();

		for (int i = 0; i < orderBook.GetOrdersCount(); i++) {
			EOrder *order = orderBook.GetOrderAtIndex(i);

			if (order == NULL || !MatchesOrderFilters(order, event)) {
				continue;
			}

			ordersArray.add(SerializeActiveOrder(order, orderBook));

			int addedSize = ArraySize(addedIds);
			ArrayResize(addedIds, addedSize + 1);
			addedIds[addedSize] = order.GetId();
			matchCount++;
		}
	}

	bool includesClosed = (event.status == "" || event.status == "closed" || event.status == "cancelled");

	if (includesClosed) {
		for (int s = 0; s < ArraySize(strategies); s++) {
			SEOrderBook *orderBook = strategies[s].GetOrderBook();
			SEDbQuery query;

			if (event.status == "closed") {
				query.WhereEquals("status", (double)ORDER_STATUS_CLOSED);
			} else if (event.status == "cancelled") {
				query.WhereEquals("status", (double)ORDER_STATUS_CANCELLED);
			}

			if (event.symbol != "") {
				query.WhereEquals("symbol", event.symbol);
			}

			JSON::Object *results[];
			int found = orderBook.QueryPersistedOrders(query, results);

			for (int i = 0; i < found; i++) {
				if (results[i] == NULL || !results[i].hasValue("_id")) {
					continue;
				}

				string orderId = results[i].getString("_id");

				if (IsDuplicateId(addedIds, orderId)) {
					continue;
				}

				int orderStatus = (int)results[i].getNumber("status");

				if (orderStatus != ORDER_STATUS_CLOSED && orderStatus != ORDER_STATUS_CANCELLED) {
					continue;
				}

				if (event.side != "" && GetOrderSide((int)results[i].getNumber("side")) != event.side) {
					continue;
				}

				JSON::Object *orderObject = new JSON::Object();
				orderObject.setProperty("id", results[i].getString("_id"));
				orderObject.setProperty("ticket", (long)results[i].getNumber("order_id"));
				orderObject.setProperty("position_id", (long)results[i].getNumber("position_id"));
				orderObject.setProperty("symbol", results[i].getString("symbol"));
				orderObject.setProperty("side", GetOrderSide((int)results[i].getNumber("side")));
				orderObject.setProperty("status", GetOrderStatus((ENUM_ORDER_STATUSES)orderStatus));
				orderObject.setProperty("volume", results[i].getNumber("volume"));
				orderObject.setProperty("open_price", results[i].getNumber("open_price"));
				orderObject.setProperty("stop_loss", SanitizePrice(results[i].getNumber("stop_loss_price")));
				orderObject.setProperty("take_profit", SanitizePrice(results[i].getNumber("take_profit_price")));
				orderObject.setProperty("close_price", results[i].getNumber("close_price"));
				orderObject.setProperty("profit", results[i].getNumber("profit_in_dollars"));
				orderObject.setProperty("floating_pnl", 0.0);
				ordersArray.add(orderObject);

				int addedSize = ArraySize(addedIds);
				ArrayResize(addedIds, addedSize + 1);
				addedIds[addedSize] = orderId;
				matchCount++;
			}
		}
	}

	JSON::Object ackBody;
	ackBody.setProperty("status", "ok");
	ackBody.setProperty("count", matchCount);
	ackBody.setProperty("orders", ordersArray);
	horizonGateway.AckEvent(event.id, ackBody);

	eventLogger.Info(StringFormat("get.orders acked | %d orders returned", matchCount));
}

#endif
