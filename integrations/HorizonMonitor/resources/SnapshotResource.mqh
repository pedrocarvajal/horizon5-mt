#ifndef __MONITOR_SNAPSHOT_RESOURCE_MQH__
#define __MONITOR_SNAPSHOT_RESOURCE_MQH__

#include "../../../entities/EAccount.mqh"

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetSnapshotEvent.mqh"

#include "../HorizonMonitorContext.mqh"

#include "StrategyResource.mqh"

class SnapshotResource {
private:
	HorizonMonitorContext * context;
	StrategyResource *strategies;
	EAccount account;

public:
	SnapshotResource(HorizonMonitorContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void StoreAccount(double floatingPnl, double realizedPnl, ENUM_SNAPSHOT_EVENT event) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("balance", ClampNumeric(account.GetBalance(), 13, 2));
		body.setProperty("equity", ClampNumeric(account.GetEquity(), 13, 2));
		body.setProperty("margin", ClampNumeric(account.GetMargin(), 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
		body.setProperty("event", GetSnapshotEvent(event));

		context.Post("api/v1/accounts/snapshots", body);
	}

	void StoreStrategy(
		ulong magicNumber,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		ENUM_SNAPSHOT_EVENT event
	) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("strategy_id", strategies.GetUuid(magicNumber));
		body.setProperty("balance", ClampNumeric(balance, 13, 2));
		body.setProperty("equity", ClampNumeric(equity, 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
		body.setProperty("event", GetSnapshotEvent(event));

		context.Post("api/v1/strategies/snapshots", body);
	}
};

#endif
