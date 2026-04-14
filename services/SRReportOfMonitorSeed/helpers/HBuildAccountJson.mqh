#ifndef __H_BUILD_ACCOUNT_JSON_MQH__
#define __H_BUILD_ACCOUNT_JSON_MQH__

#include "../../../entities/EAccount.mqh"

#include "../../../libraries/Json/index.mqh"

JSON::Object *BuildAccountJson(EAccount &tradingAccount, string accountUuid) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("id", accountUuid);
	obj.setProperty("account_number", tradingAccount.GetNumber());
	obj.setProperty("broker_server", tradingAccount.GetBrokerServer());
	obj.setProperty("broker_name", tradingAccount.GetBrokerName());
	obj.setProperty("currency", tradingAccount.GetCurrency());
	obj.setProperty("status", "active");

	return obj;
}

#endif
