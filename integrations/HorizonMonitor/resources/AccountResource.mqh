#ifndef __MONITOR_ACCOUNT_RESOURCE_MQH__
#define __MONITOR_ACCOUNT_RESOURCE_MQH__

#include "../../../entities/EAccount.mqh"

#include "../../../helpers/HGetAccountUuid.mqh"

#include "../HorizonMonitorContext.mqh"

#include "../../../services/SERequest/structs/SRequestResponse.mqh"

class AccountResource {
private:
	HorizonMonitorContext * context;
	SELogger logger;
	EAccount account;

	bool hasHttpFailed(SRequestResponse &response, const string failurePrefix) {
		if (response.status >= 200 && response.status < 300) {
			return false;
		}

		logger.Error(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"%s status=%d body='%s'",
				failurePrefix,
				response.status,
				response.body
		));

		return true;
	}

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

		SRequestResponse response = context.Post("api/v1/account", body, false);

		if (hasHttpFailed(response, "account upsert failed |")) {
			return false;
		}

		context.SetAccountUuid(accountUuid);
		logger.Info(
			LOG_CODE_REMOTE_HTTP_OK,
			StringFormat(
				"account registered | uuid=%s",
				accountUuid
		));

		return true;
	}
};

#endif
