#ifndef __MONITOR_ASSET_METADATA_RESOURCE_MQH__
#define __MONITOR_ASSET_METADATA_RESOURCE_MQH__

#include "../../../entities/EAsset.mqh"

#include "../HorizonMonitorContext.mqh"

class AssetMetadataResource {
private:
	HorizonMonitorContext * context;

public:
	AssetMetadataResource(HorizonMonitorContext * ctx) {
		context = ctx;
	}

	void Upsert(string assetUuid, string symbolName) {
		string path = StringFormat("api/v1/asset/%s/metadata", assetUuid);

		int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
		EAsset asset(symbolName);
		JSON::Array *entries = asset.GetMetadata(leverage);

		JSON::Object body;
		body.setProperty("items", entries);

		context.Post(path, body);
	}
};

#endif
