#ifndef __H_BUILD_ORDER_OPENED_PAYLOAD_MQH__
#define __H_BUILD_ORDER_OPENED_PAYLOAD_MQH__

#include "../../../entities/EOrder.mqh"
#include "../../../libraries/Json/index.mqh"

#include "./HBuildOrderPayloadCommon.mqh"

void BuildOrderOpenedPayload(EOrder &order, JSON::Object *payload) {
	BuildOrderPayloadCommon(order, payload);
	payload.setProperty("open_time", (long)order.GetOpenAt().timestamp);
}

#endif
