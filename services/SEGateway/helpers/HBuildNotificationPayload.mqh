#ifndef __H_BUILD_NOTIFICATION_PAYLOAD_MQH__
#define __H_BUILD_NOTIFICATION_PAYLOAD_MQH__

#include "../../../entities/EOrder.mqh"
#include "../../../helpers/HIsBuySide.mqh"
#include "../../../libraries/Json/index.mqh"

void BuildOrderPayloadCommon(EOrder &order, JSON::Object *payload) {
	payload.setProperty("order_id", order.GetId());
	payload.setProperty("position_id", (long)order.GetPositionId());
	payload.setProperty("ticket", (long)order.GetOrderId());
	payload.setProperty("side", IsBuySide((ENUM_ORDER_TYPE)order.GetSide()) ? "buy" : "sell");
	payload.setProperty("volume", order.GetVolume());
	payload.setProperty("open_price", order.GetOpenPrice());
	payload.setProperty("stop_loss", order.GetStopLossPrice());
	payload.setProperty("take_profit", order.GetTakeProfitPrice());
	payload.setProperty("source", order.GetSource());
}

void BuildOrderOpenedPayload(EOrder &order, JSON::Object *payload) {
	BuildOrderPayloadCommon(order, payload);
	payload.setProperty("open_time", (long)order.GetOpenAt().timestamp);
}

void BuildOrderClosedPayload(EOrder &order, ENUM_DEAL_REASON reason, JSON::Object *payload) {
	BuildOrderPayloadCommon(order, payload);
	payload.setProperty("close_price", order.GetClosePrice());
	payload.setProperty("open_time", (long)order.GetOpenAt().timestamp);
	payload.setProperty("close_time", (long)order.GetCloseAt().timestamp);
	payload.setProperty("profit", order.GetProfitInDollars());
	payload.setProperty("commission", order.GetCommission());
	payload.setProperty("swap", order.GetSwap());
	payload.setProperty("gross_profit", order.GetGrossProfit());
	payload.setProperty("close_reason", (int)reason);
}

void BuildOrderCancelledPayload(EOrder &order, JSON::Object *payload) {
	BuildOrderPayloadCommon(order, payload);
}

void BuildOrderModifiedPayload(EOrder &order, JSON::Object *payload) {
	BuildOrderPayloadCommon(order, payload);
}

#endif
