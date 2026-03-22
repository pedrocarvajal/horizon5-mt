#ifndef __MONITOR_ACCOUNT_METADATA_RESOURCE_MQH__
#define __MONITOR_ACCOUNT_METADATA_RESOURCE_MQH__

#include "../../../entities/EAccount.mqh"

#include "../HorizonMonitorContext.mqh"

class AccountMetadataResource {
private:
	HorizonMonitorContext * context;
	EAccount account;

public:
	AccountMetadataResource(HorizonMonitorContext * ctx) {
		context = ctx;
	}

	void Upsert() {
		string accountUuid = context.GetAccountUuid();

		if (accountUuid == "") {
			return;
		}

		string path = StringFormat("api/v1/account/%s/metadata", accountUuid);
		JSON::Array *entries = account.GetMetadata();

		JSON::Object body;
		body.setProperty("items", entries);

		context.Post(path, body);
	}
};

#endif
