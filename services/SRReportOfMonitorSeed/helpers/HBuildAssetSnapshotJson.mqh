#ifndef __H_BUILD_ASSET_SNAPSHOT_JSON_MQH__
#define __H_BUILD_ASSET_SNAPSHOT_JSON_MQH__

#include "../../../libraries/Json/index.mqh"

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetSnapshotEvent.mqh"

JSON::Object *BuildAssetSnapshotJson(
	string assetUuid,
	double balance,
	double equity,
	double floatingPnl,
	double realizedPnl,
	double bid,
	double ask,
	double usdRate,
	ENUM_SNAPSHOT_EVENT event,
	long timestamp
) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("asset_id", assetUuid);
	obj.setProperty("balance", ClampNumeric(balance, 13, 2));
	obj.setProperty("equity", ClampNumeric(equity, 13, 2));
	obj.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
	obj.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
	obj.setProperty("bid", ClampNumeric(bid, 10, 5));
	obj.setProperty("ask", ClampNumeric(ask, 10, 5));
	obj.setProperty("usd_rate", ClampNumeric(usdRate, 7, 8));
	obj.setProperty("event", GetSnapshotEvent(event));
	obj.setProperty("created_at", timestamp);

	return obj;
}

#endif
