#ifndef __H_GET_ACCOUNT_UUID_MQH__
#define __H_GET_ACCOUNT_UUID_MQH__

#include "HGenerateDeterministicUuid.mqh"

string GetDeterministicAccountUuid(long accountNumber, string brokerServer) {
	return GenerateDeterministicUuid(
		StringFormat("account:%lld:%s", accountNumber, brokerServer)
	);
}

#endif
