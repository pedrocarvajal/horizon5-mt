#ifndef __H_BUILD_METADATA_ENTRY_JSON_MQH__
#define __H_BUILD_METADATA_ENTRY_JSON_MQH__

#include "../../../libraries/Json/index.mqh"

#include "../../../helpers/HGenerateDeterministicUuid.mqh"

JSON::Object *BuildMetadataEntryJson(
	string parentId,
	string parentType,
	string key,
	string label,
	string value,
	string format
) {
	string metadataUuid = GenerateDeterministicUuid(
		StringFormat("%s:%s:%s", parentType, parentId, key)
	);

	JSON::Object *obj = new JSON::Object();
	obj.setProperty("id", metadataUuid);

	if (parentType == "account_metadata") {
		obj.setProperty("account_id", parentId);
	} else {
		obj.setProperty("asset_id", parentId);
	}

	obj.setProperty("key", key);
	obj.setProperty("label", label);
	obj.setProperty("value", value);
	obj.setProperty("format", format);

	return obj;
}

#endif
