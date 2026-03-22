#ifndef __H_GET_ASSET_UUID_MQH__
#define __H_GET_ASSET_UUID_MQH__

#include "HGenerateDeterministicUuid.mqh"

string GetDeterministicAssetUuid(long accountNumber, string brokerServer, string symbol) {
	return GenerateDeterministicUuid(
		StringFormat("asset:%lld:%s:%s", accountNumber, brokerServer, symbol)
	);
}

#endif
