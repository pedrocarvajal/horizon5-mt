#ifndef __ASSET_ENROLLER_MQH__
#define __ASSET_ENROLLER_MQH__

#include "../../../entities/EAccount.mqh"
#include "../../../entities/EAsset.mqh"

#include "../../../helpers/HGetAssetUuid.mqh"
#include "../helpers/HBuildAssetJson.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "MetadataExporter.mqh"

#include "UuidRegistry.mqh"

class AssetEnroller {
private:
	SELogger logger;
	SEDbCollection *assetsCollection;
	MetadataExporter *metadataExporter;
	UuidRegistry *registry;

public:
	AssetEnroller() {
		logger.SetPrefix("MonitorSeed::AssetEnroller");
		assetsCollection = NULL;
		metadataExporter = NULL;
		registry = NULL;
	}

	void Initialize(SEDbCollection *assetsRef, MetadataExporter *exporter, UuidRegistry *uuidRegistry) {
		assetsCollection = assetsRef;
		metadataExporter = exporter;
		registry = uuidRegistry;
	}

	void Enroll(string symbolName, EAccount &tradingAccount, string accountUuid) {
		string assetUuid = GetDeterministicAssetUuid(tradingAccount.GetNumber(), tradingAccount.GetBrokerServer(), symbolName);
		registry.RegisterAsset(symbolName, assetUuid);

		if (EnableSeedAssets) {
			JSON::Object *json = BuildAssetJson(symbolName, assetUuid, accountUuid);
			assetsCollection.InsertOne(json);
			delete json;
		}

		if (EnableSeedMetadata) {
			int leverage = tradingAccount.GetLeverage();
			EAsset asset(symbolName);
			JSON::Array *metadataEntries = asset.GetMetadata(leverage);
			metadataExporter.ExportAssetMetadata(metadataEntries, assetUuid);
			delete metadataEntries;
		}

		logger.Info(LOG_CODE_STATS_EXPORT_FAILED, StringFormat("Enrolled asset %s -> %s", symbolName, assetUuid));
	}
};

#endif
