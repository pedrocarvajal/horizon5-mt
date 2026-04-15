#ifndef __H_SERIALIZE_ACTIVE_ORDER_MQH__
#define __H_SERIALIZE_ACTIVE_ORDER_MQH__

JSON::Object *SEGateway::serializeActiveOrder(EOrder *order, SEOrderBook *orderBook) {
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
	orderObject.setProperty("floating_pnl", order.GetFloatingPnL());
	return orderObject;
}

#endif
