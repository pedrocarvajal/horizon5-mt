#ifndef __MONITOR_LOG_RESOURCE_MQH__
#define __MONITOR_LOG_RESOURCE_MQH__

#include "../HorizonMonitorContext.mqh"

#include "StrategyResource.mqh"

class LogResource {
private:
	HorizonMonitorContext * context;
	StrategyResource *strategies;

public:
	LogResource(HorizonMonitorContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void Store(string system, string level, string message, ulong magicNumber = 0) {
		string normalizedLevel = level;
		StringToLower(normalizedLevel);

		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("system", system);
		body.setProperty("level", normalizedLevel);
		body.setProperty("message", message);

		if (magicNumber > 0) {
			body.setProperty("strategy_id", strategies.GetUuid(magicNumber));
		}

		context.Post("api/v1/log", body);
	}
};

#endif
