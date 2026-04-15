#ifndef __SR_ACCOUNT_AUDITOR_MQH__
#define __SR_ACCOUNT_AUDITOR_MQH__

#include "../SELogger/SELogger.mqh"

#include "../SEDateTime/SEDateTime.mqh"

#include "../SRReportOfMonitorSeed/SRReportOfMonitorSeed.mqh"

#include "../../entities/EAccount.mqh"

#include "../../assets/Asset.mqh"

#include "../../helpers/HIsLiveTrading.mqh"
#include "../../helpers/HGetSnapshotEvent.mqh"

extern SEDateTime dtime;
extern EAccount account;
extern SRReportOfMonitorSeed *monitorSeedReporter;

class SRAccountAuditor {
private:
	SELogger logger;
	SEAsset *registeredAssets[];
	int assetCount;

public:
	SRAccountAuditor() {
		logger.SetPrefix("AccountAuditor");
		assetCount = 0;
	}

	void Initialize(SEAsset *&sourceAssets[], int count) {
		assetCount = count;
		ArrayResize(registeredAssets, assetCount);

		for (int i = 0; i < assetCount; i++) {
			registeredAssets[i] = sourceAssets[i];
		}
	}

	void AuditOrders() {
		if (!IsLiveTrading()) {
			return;
		}

		int trackedOrderCount = 0;

		for (int i = 0; i < assetCount; i++) {
			if (!registeredAssets[i].IsEnabled()) {
				continue;
			}

			for (int j = 0; j < registeredAssets[i].GetStrategyCount(); j++) {
				SEOrderBook *book = registeredAssets[i].GetStrategyAtIndex(j).GetOrderBook();
				trackedOrderCount += book.GetActiveOrderCount();
			}
		}

		int metatraderPositions = PositionsTotal();
		int metatraderPendingOrders = OrdersTotal();
		int metatraderTotal = metatraderPositions + metatraderPendingOrders;

		logger.Info(
			LOG_CODE_ORDER_NOT_FOUND,
			StringFormat(
				"Order summary (enabled assets only) | MT5 positions: %d | MT5 pending: %d | Tracked orders: %d",
				metatraderPositions,
				metatraderPendingOrders,
				trackedOrderCount
		));

		if (metatraderTotal != trackedOrderCount) {
			logger.Warning(
				LOG_CODE_ORDER_NOT_FOUND,
				StringFormat(
					"Order discrepancy detected (enabled assets only) | MT5 total: %d | Tracked: %d | Diff: %d",
					metatraderTotal,
					trackedOrderCount,
					metatraderTotal - trackedOrderCount
			));
		}
	}

	void CollectAccountSeedSnapshot(ENUM_SNAPSHOT_EVENT event) {
		if (monitorSeedReporter == NULL) {
			return;
		}

		double floatingPnl = 0;
		double realizedPnl = 0;

		for (int i = 0; i < assetCount; i++) {
			registeredAssets[i].AggregateSnapshotData(floatingPnl, realizedPnl);
		}

		monitorSeedReporter.AddAccountSnapshot(
			account.GetBalance(),
			account.GetEquity(),
			account.GetMargin(),
			floatingPnl,
			realizedPnl,
			event,
			dtime.Timestamp()
		);
	}
};

#endif
