#ifndef __HEARTBEAT_RESOURCE_MQH__
#define __HEARTBEAT_RESOURCE_MQH__

#include "../helpers/HGetHeartbeatEvent.mqh"

#include "../HorizonAPIContext.mqh"
#include "StrategyResource.mqh"

class HeartbeatResource {
private:
	HorizonAPIContext * context;
	StrategyResource *strategies;

public:
	HeartbeatResource(HorizonAPIContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void Store(ulong magicNumber, ENUM_HEARTBEAT_EVENT event, string systemName = "strategy") {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("strategy_id", strategies.GetUUID(magicNumber));
		body.setProperty("event", GetHeartbeatEvent(event));
		body.setProperty("system", systemName);

		context.Post("api/v1/heartbeat/", body);
	}

	void StoreSystem(ENUM_HEARTBEAT_EVENT event) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("event", GetHeartbeatEvent(event));
		body.setProperty("system", "system");

		context.Post("api/v1/heartbeat/", body);
	}
};

#endif
