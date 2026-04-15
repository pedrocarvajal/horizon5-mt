#ifndef __H_BUILD_ORDER_PAYLOAD_COMMON_MQH__
#define __H_BUILD_ORDER_PAYLOAD_COMMON_MQH__

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

#endif
