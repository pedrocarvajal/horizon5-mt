#ifndef __METADATA_EXPORTER_MQH__
#define __METADATA_EXPORTER_MQH__

#include "../../../libraries/Json/index.mqh"

#include "../../SEDb/SEDb.mqh"

#include "../helpers/HBuildMetadataEntryJson.mqh"

class MetadataExporter {
private:
	SEDbCollection * accountMetadataCollection;
	SEDbCollection *assetMetadataCollection;

public:
	MetadataExporter() {
		accountMetadataCollection = NULL;
		assetMetadataCollection = NULL;
	}

	void Initialize(SEDbCollection *accountMetadata, SEDbCollection *assetMetadata) {
		accountMetadataCollection = accountMetadata;
		assetMetadataCollection = assetMetadata;
	}

	void ExportAccountMetadata(JSON::Array *entries, string accountUuid) {
		exportEntries(entries, accountUuid, "account_metadata", accountMetadataCollection);
	}

	void ExportAssetMetadata(JSON::Array *entries, string assetUuid) {
		exportEntries(entries, assetUuid, "asset_metadata", assetMetadataCollection);
	}

private:
	void exportEntries(
		JSON::Array *entries,
		string parentId,
		string parentType,
		SEDbCollection *collection
	) {
		for (int i = 0; i < entries.getLength(); i++) {
			JSON::Object *entry = entries.getObject(i);

			if (entry == NULL) {
				continue;
			}

			string key = entry.getString("key");
			string label = entry.getString("label");
			string value = entry.getString("value");
			string format = entry.getString("format");

			JSON::Object *metaJson = BuildMetadataEntryJson(parentId, parentType, key, label, value, format);
			collection.InsertOne(metaJson);
			delete metaJson;
		}
	}
};

#endif
