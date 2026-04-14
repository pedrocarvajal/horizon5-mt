#ifndef __H_BUILD_ACCOUNT_SNAPSHOT_JSON_MQH__
#define __H_BUILD_ACCOUNT_SNAPSHOT_JSON_MQH__

#include "../../../libraries/Json/index.mqh"

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetSnapshotEvent.mqh"

JSON::Object *BuildAccountSnapshotJson(
	string accountUuid,
	double balance,
	double equity,
	double margin,
	double floatingPnl,
	double realizedPnl,
	ENUM_SNAPSHOT_EVENT event,
	long timestamp
) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("account_id", accountUuid);
	obj.setProperty("balance", ClampNumeric(balance, 13, 2));
	obj.setProperty("equity", ClampNumeric(equity, 13, 2));
	obj.setProperty("margin", ClampNumeric(margin, 13, 2));
	obj.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
	obj.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
	obj.setProperty("event", GetSnapshotEvent(event));
	obj.setProperty("created_at", timestamp);

	return obj;
}

#endif
