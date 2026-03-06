#ifndef __LOG_RESOURCE_MQH__
#define __LOG_RESOURCE_MQH__

#include "../HorizonAPIContext.mqh"
#include "StrategyResource.mqh"

class LogResource {
private:
	HorizonAPIContext * context;
	StrategyResource *strategies;

public:
	LogResource(HorizonAPIContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void Store(string level, string message, ulong magicNumber = 0) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("level", level);
		body.setProperty("message", message);

		if (magicNumber > 0) {
			body.setProperty("strategy_id", strategies.GetUUID(magicNumber));
		}

		context.Post("api/v1/log/", body);
	}
};

#endif
