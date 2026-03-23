#ifndef __H_GET_ORDER_UUID_MQH__
#define __H_GET_ORDER_UUID_MQH__

#include "HGenerateDeterministicUuid.mqh"

string GetDeterministicOrderUuid(long accountNumber, string brokerServer, string symbol, ulong magicNumber, ulong orderId, ulong positionId) {
	return GenerateDeterministicUuid(
		StringFormat("order:%lld:%s:%s:%llu:%llu:%llu", accountNumber, brokerServer, symbol, magicNumber, orderId, positionId)
	);
}

#endif
