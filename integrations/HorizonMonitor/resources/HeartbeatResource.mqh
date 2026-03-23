#ifndef __MONITOR_HEARTBEAT_RESOURCE_MQH__
#define __MONITOR_HEARTBEAT_RESOURCE_MQH__

#include "../HorizonMonitorContext.mqh"
#include "StrategyResource.mqh"

#define HEARTBEAT_EVENT_RUNNING "on_running"

class HeartbeatResource {
private:
	HorizonMonitorContext * context;
	StrategyResource *strategies;

public:
	HeartbeatResource(HorizonMonitorContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void Store(ulong magicNumber, string systemName = "horizon5") {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("strategy_id", strategies.GetUuid(magicNumber));
		body.setProperty("event", HEARTBEAT_EVENT_RUNNING);
		body.setProperty("system", systemName);

		context.Post("api/v1/heartbeat", body);
	}

	void StoreSystem(string systemName) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("event", HEARTBEAT_EVENT_RUNNING);
		body.setProperty("system", systemName);

		context.Post("api/v1/heartbeat", body);
	}
};

#endif
