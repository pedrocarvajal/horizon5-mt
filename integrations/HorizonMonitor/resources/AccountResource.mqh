#ifndef __MONITOR_ACCOUNT_RESOURCE_MQH__
#define __MONITOR_ACCOUNT_RESOURCE_MQH__

#include "../../../entities/EAccount.mqh"
#include "../../../helpers/HGetAccountUuid.mqh"

#include "../HorizonMonitorContext.mqh"

class AccountResource {
private:
	HorizonMonitorContext * context;
	SELogger logger;
	EAccount account;

public:
	AccountResource(HorizonMonitorContext * ctx) {
		context = ctx;
		logger.SetPrefix("Monitor::Account");
	}

	bool Upsert() {
		string accountUuid = GetDeterministicAccountUuid(account.GetNumber(), account.GetBrokerServer());

		JSON::Object body;
		body.setProperty("id", accountUuid);
		body.setProperty("account_number", account.GetNumber());
		body.setProperty("broker_server", account.GetBrokerServer());
		body.setProperty("broker_name", account.GetBrokerName());
		body.setProperty("currency", account.GetCurrency());

		context.Post("api/v1/account", body, false);

		context.SetAccountUuid(accountUuid);
		logger.Info(StringFormat("Account registered | uuid: %s", accountUuid));

		return true;
	}
};

#endif
