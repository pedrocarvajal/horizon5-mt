#ifndef __MONITOR_STRATEGY_RESOURCE_MQH__
#define __MONITOR_STRATEGY_RESOURCE_MQH__

#include "../../../entities/EAccount.mqh"

#include "../../../helpers/HGetStrategyUuid.mqh"

#include "../HorizonMonitorContext.mqh"

#include "../../../services/SERequest/structs/SRequestResponse.mqh"

#include "../structs/SStrategyMapping.mqh"

class StrategyResource {
private:
	HorizonMonitorContext * context;
	SELogger logger;
	EAccount account;

	SStrategyMapping registeredStrategies[];

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

	void registerStrategy(ulong magicNumber, string uuid) {
		for (int i = 0; i < ArraySize(registeredStrategies); i++) {
			if (registeredStrategies[i].GetMagicNumber() == magicNumber) {
				registeredStrategies[i].SetUuid(uuid);
				return;
			}
		}

		int size = ArraySize(registeredStrategies);
		ArrayResize(registeredStrategies, size + 1);
		registeredStrategies[size].SetMagicNumber(magicNumber);
		registeredStrategies[size].SetUuid(uuid);
	}

public:
	StrategyResource(HorizonMonitorContext * ctx) {
		context = ctx;
		logger.SetPrefix("Monitor::Strategy");
	}

	string GetUuid(ulong magicNumber) {
		for (int i = 0; i < ArraySize(registeredStrategies); i++) {
			if (registeredStrategies[i].GetMagicNumber() == magicNumber) {
				return registeredStrategies[i].GetUuid();
			}
		}

		return "";
	}

	string Upsert(
		string strategyName,
		string symbol,
		string prefix,
		ulong magicNumber
	) {
		string strategyUuid = GetDeterministicStrategyUuid(account.GetNumber(), account.GetBrokerServer(), symbol, prefix, strategyName);

		JSON::Object body;
		body.setProperty("id", strategyUuid);
		body.setProperty("account_number", account.GetNumber());
		body.setProperty("broker_server", account.GetBrokerServer());
		body.setProperty("symbol", symbol);
		body.setProperty("prefix", prefix);
		body.setProperty("name", strategyName);
		body.setProperty("magic_number", (long)magicNumber);

		SRequestResponse response = context.Post("api/v1/strategy", body, false);

		string failurePrefix = StringFormat("strategy upsert failed | name=%s magic=%llu", strategyName, magicNumber);
		if (hasHttpFailed(response, failurePrefix)) {
			return "";
		}

		registerStrategy(magicNumber, strategyUuid);
		logger.Info(
			LOG_CODE_REMOTE_HTTP_OK,
			StringFormat(
				"strategy registered | name=%s magic=%llu uuid=%s",
				strategyName,
				magicNumber,
				strategyUuid
		));

		return strategyUuid;
	}
};

#endif
