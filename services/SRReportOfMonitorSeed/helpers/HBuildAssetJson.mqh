#ifndef __H_BUILD_ASSET_JSON_MQH__
#define __H_BUILD_ASSET_JSON_MQH__

#include "../../../libraries/Json/index.mqh"

JSON::Object *BuildAssetJson(string symbolName, string assetUuid, string accountUuid) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("id", assetUuid);
	obj.setProperty("account_id", accountUuid);
	obj.setProperty("name", symbolName);
	obj.setProperty("symbol", symbolName);

	return obj;
}

#endif
