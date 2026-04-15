#ifndef __STRATEGY_ENROLLER_MQH__
#define __STRATEGY_ENROLLER_MQH__

#include "../../../entities/EAccount.mqh"

#include "../../../helpers/HGetStrategyUuid.mqh"
#include "../helpers/HBuildStrategyJson.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "UuidRegistry.mqh"

class StrategyEnroller {
private:
	SELogger logger;
	SEDbCollection *strategiesCollection;
	UuidRegistry *registry;

public:
	StrategyEnroller() {
		logger.SetPrefix("MonitorSeed::StrategyEnroller");
		strategiesCollection = NULL;
		registry = NULL;
	}

	void Initialize(SEDbCollection *strategies, UuidRegistry *uuidRegistry) {
		strategiesCollection = strategies;
		registry = uuidRegistry;
	}

	void Enroll(
		string strategyName,
		string symbolName,
		string strategyPrefix,
		ulong magicNumber,
		EAccount &tradingAccount,
		string accountUuid
	) {
		string strategyUuid = GetDeterministicStrategyUuid(
			tradingAccount.GetNumber(), tradingAccount.GetBrokerServer(),
			symbolName, strategyPrefix, strategyName
		);
		registry.RegisterStrategy(magicNumber, strategyUuid);

		if (EnableSeedStrategies) {
			string assetUuid = registry.GetAssetUuid(symbolName);
			JSON::Object *json = BuildStrategyJson(
				strategyName, strategyPrefix, magicNumber, strategyUuid, accountUuid, assetUuid
			);
			strategiesCollection.InsertOne(json);
			delete json;
		}

		logger.Info(
			LOG_CODE_STATS_EXPORT_FAILED,
			StringFormat(
				"Enrolled strategy %s (%llu) -> %s",
				strategyName,
				magicNumber,
				strategyUuid
		));
	}
};

#endif
