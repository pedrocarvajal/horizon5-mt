#ifndef __MONITOR_HEARTBEAT_RESOURCE_MQH__
#define __MONITOR_HEARTBEAT_RESOURCE_MQH__

#include "../../../helpers/HGetHeartbeatEvent.mqh"

#include "../HorizonMonitorContext.mqh"
#include "StrategyResource.mqh"

class HeartbeatResource {
private:
	HorizonMonitorContext * context;
	StrategyResource *strategies;

public:
	HeartbeatResource(HorizonMonitorContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void Store(ulong magicNumber, ENUM_HEARTBEAT_EVENT event, string systemName = "strategy") {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("strategy_id", strategies.GetUuid(magicNumber));
		body.setProperty("event", GetHeartbeatEvent(event));
		body.setProperty("system", systemName);

		context.Post("api/v1/heartbeat", body);
	}

	void StoreSystem(ENUM_HEARTBEAT_EVENT event) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("event", GetHeartbeatEvent(event));
		body.setProperty("system", "system");

		context.Post("api/v1/heartbeat", body);
	}
};

#endif
