#ifndef __H_BUILD_STRATEGY_JSON_MQH__
#define __H_BUILD_STRATEGY_JSON_MQH__

#include "../../../libraries/Json/index.mqh"

JSON::Object *BuildStrategyJson(
	string strategyName,
	string strategyPrefix,
	ulong magicNumber,
	string strategyUuid,
	string accountUuid,
	string assetUuid
) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("id", strategyUuid);
	obj.setProperty("account_id", accountUuid);
	obj.setProperty("asset_id", assetUuid);
	obj.setProperty("prefix", strategyPrefix);
	obj.setProperty("name", strategyName);
	obj.setProperty("magic_number", (long)magicNumber);

	return obj;
}

#endif
