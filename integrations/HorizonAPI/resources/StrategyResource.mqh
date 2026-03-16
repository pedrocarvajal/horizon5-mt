#ifndef __STRATEGY_RESOURCE_MQH__
#define __STRATEGY_RESOURCE_MQH__

#include "../structs/SStrategyMapping.mqh"

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGenerateUuid.mqh"

#include "../HorizonAPIContext.mqh"

class StrategyResource {
private:
	HorizonAPIContext * context;
	SELogger logger;

	SStrategyMapping registeredStrategies[];

	void registerStrategy(ulong magicNumber) {
		for (int i = 0; i < ArraySize(registeredStrategies); i++) {
			if (registeredStrategies[i].magicNumber == magicNumber) {
				return;
			}
		}

		int size = ArraySize(registeredStrategies);
		ArrayResize(registeredStrategies, size + 1);
		registeredStrategies[size].magicNumber = magicNumber;
		registeredStrategies[size].uuid = MagicNumberToUuid(magicNumber);
	}

public:
	StrategyResource(HorizonAPIContext * ctx) {
		context = ctx;
		logger.SetPrefix("StrategyResource");
	}

	string GetUUID(ulong magicNumber) {
		for (int i = 0; i < ArraySize(registeredStrategies); i++) {
			if (registeredStrategies[i].magicNumber == magicNumber) {
				return registeredStrategies[i].uuid;
			}
		}

		return MagicNumberToUuid(magicNumber);
	}

	void Upsert(
		string strategyName,
		string symbol,
		string prefix,
		ulong magicNumber,
		double balance
	) {
		registerStrategy(magicNumber);

		JSON::Object body;
		body.setProperty("id", GetUUID(magicNumber));
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("name", strategyName);
		body.setProperty("symbol", symbol);
		body.setProperty("prefix", prefix);
		body.setProperty("magic_number", (long)magicNumber);
		body.setProperty("balance", ClampNumeric(balance, 13, 2));

		context.Post("api/v1/strategy/", body);
	}
};

#endif
