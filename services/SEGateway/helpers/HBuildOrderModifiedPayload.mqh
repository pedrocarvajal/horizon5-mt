#ifndef __H_BUILD_ORDER_MODIFIED_PAYLOAD_MQH__
#define __H_BUILD_ORDER_MODIFIED_PAYLOAD_MQH__

#include "../../../entities/EOrder.mqh"
#include "../../../libraries/Json/index.mqh"

#include "./HBuildOrderPayloadCommon.mqh"

void BuildOrderModifiedPayload(EOrder &order, JSON::Object *payload) {
	BuildOrderPayloadCommon(order, payload);
}

#endif
