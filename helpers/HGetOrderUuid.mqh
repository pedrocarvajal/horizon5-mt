#ifndef __H_GET_ORDER_UUID_MQH__
#define __H_GET_ORDER_UUID_MQH__

#include "HGenerateDeterministicUuid.mqh"

/**
 * Stable order UUID for the full lifecycle (pending → open → closed).
 * We hash only orderId (MT5 ticket) because in MT5 the pending ticket is
 * reused as the position ticket after fill, and orderId is set the moment
 * the order is placed and never changes. Including positionId would break
 * the hash across the pending → open transition (positionId is 0 while
 * pending) and create an orphan "pending" row in the monitor for every
 * pending that eventually fills.
 */
string GetDeterministicOrderUuid(long accountNumber, string brokerServer, string symbol, ulong magicNumber, ulong orderId) {
	return GenerateDeterministicUuid(
		StringFormat("order:%lld:%s:%s:%llu:%llu", accountNumber, brokerServer, symbol, magicNumber, orderId)
	);
}

#endif
