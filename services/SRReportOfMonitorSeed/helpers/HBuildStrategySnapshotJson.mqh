#ifndef __H_BUILD_STRATEGY_SNAPSHOT_JSON_MQH__
#define __H_BUILD_STRATEGY_SNAPSHOT_JSON_MQH__

#include "../../../libraries/Json/index.mqh"

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetSnapshotEvent.mqh"

JSON::Object *BuildStrategySnapshotJson(
	string accountUuid,
	string strategyUuid,
	double balance,
	double equity,
	double floatingPnl,
	double realizedPnl,
	ENUM_SNAPSHOT_EVENT event,
	long timestamp
) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("account_id", accountUuid);
	obj.setProperty("strategy_id", strategyUuid);
	obj.setProperty("balance", ClampNumeric(balance, 13, 2));
	obj.setProperty("equity", ClampNumeric(equity, 13, 2));
	obj.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
	obj.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
	obj.setProperty("event", GetSnapshotEvent(event));
	obj.setProperty("created_at", timestamp);

	return obj;
}

#endif
