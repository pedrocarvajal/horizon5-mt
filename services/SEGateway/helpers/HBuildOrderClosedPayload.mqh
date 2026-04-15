#ifndef __H_BUILD_ORDER_CLOSED_PAYLOAD_MQH__
#define __H_BUILD_ORDER_CLOSED_PAYLOAD_MQH__

#include "../../../entities/EOrder.mqh"
#include "../../../libraries/Json/index.mqh"

#include "./HBuildOrderPayloadCommon.mqh"

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

#endif
