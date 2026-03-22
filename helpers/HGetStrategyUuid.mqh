#ifndef __H_GET_STRATEGY_UUID_MQH__
#define __H_GET_STRATEGY_UUID_MQH__

#include "HGenerateDeterministicUuid.mqh"

string GetDeterministicStrategyUuid(long accountNumber, string brokerServer, string symbol, string prefix, string strategyName) {
	return GenerateDeterministicUuid(
		StringFormat("strategy:%lld:%s:%s:%s:%s", accountNumber, brokerServer, symbol, prefix, strategyName)
	);
}

#endif
