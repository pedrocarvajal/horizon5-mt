#ifndef __SNAPSHOT_RESOURCE_MQH__
#define __SNAPSHOT_RESOURCE_MQH__

#include "../../../helpers/HClampNumeric.mqh"

#include "../HorizonAPIContext.mqh"
#include "../helpers/HGetSafeMarginLevel.mqh"
#include "StrategyResource.mqh"

class SnapshotResource {
private:
	HorizonAPIContext * context;
	StrategyResource *strategies;

public:
	SnapshotResource(HorizonAPIContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void StoreAccount(
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots,
		double exposureUsd
	) {
		double balance = ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2);
		double equity = ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2);

		JSON::Object body;
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("balance", balance);
		body.setProperty("equity", equity);
		body.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
		body.setProperty("margin_level", ClampNumeric(GetSafeMarginLevel(), 8, 2));
		body.setProperty("open_positions", PositionsTotal());
		body.setProperty("drawdown_pct", ClampNumeric(drawdownPct, 4, 4));
		body.setProperty("daily_pnl", ClampNumeric(dailyPnl, 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("open_order_count", openOrderCount);
		body.setProperty("exposure_lots", ClampNumeric(exposureLots, 6, 4));
		body.setProperty("exposure_usd", ClampNumeric(exposureUsd, 13, 2));

		context.Post("api/v1/accounts/snapshots/", body);
	}

	void StoreStrategy(
		ulong magicNumber,
		double nav,
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots,
		double exposureUsd
	) {
		JSON::Object body;
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("strategy_id", strategies.GetUUID(magicNumber));
		body.setProperty("nav", ClampNumeric(nav, 13, 2));
		body.setProperty("drawdown_pct", ClampNumeric(drawdownPct, 4, 4));
		body.setProperty("daily_pnl", ClampNumeric(dailyPnl, 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("open_order_count", openOrderCount);
		body.setProperty("exposure_lots", ClampNumeric(exposureLots, 6, 4));
		body.setProperty("exposure_usd", ClampNumeric(exposureUsd, 13, 2));

		context.Post("api/v1/strategies/snapshots/", body);
	}
};

#endif
