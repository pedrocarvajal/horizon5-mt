#ifndef __H_BUILD_STATISTICS_SNAPSHOT_MQH__
#define __H_BUILD_STATISTICS_SNAPSHOT_MQH__

#include "../../../structs/SSStatisticsSnapshot.mqh"
#include "../../../structs/SSQualityResult.mqh"
#include "../../../structs/SSOrderHistory.mqh"

#include "../components/NavTracker.mqh"
#include "../components/PerformanceTracker.mqh"
#include "../components/DrawdownTracker.mqh"
#include "../components/OrderHistoryTracker.mqh"

SSStatisticsSnapshot BuildStatisticsSnapshot(
	string id,
	datetime timestamp,
	NavTracker *navTracker,
	PerformanceTracker *performanceTracker,
	DrawdownTracker *drawdownTracker,
	OrderHistoryTracker *orderHistoryTracker,
	SSQualityResult &quality
) {
	SSStatisticsSnapshot snapshotData;
	snapshotData.timestamp = timestamp;
	snapshotData.id = id;

	SSOrderHistory history[];
	orderHistoryTracker.CopyOrdersHistory(history);
	ArrayResize(snapshotData.orders, ArraySize(history));
	for (int i = 0; i < ArraySize(history); i++) {
		snapshotData.orders[i] = history[i];
	}

	navTracker.CopyNav(snapshotData.nav);
	performanceTracker.CopyPerformance(snapshotData.performance);

	snapshotData.navPeak = navTracker.GetPeak();
	snapshotData.drawdownMaxInDollars = drawdownTracker.GetMaxInDollars();
	snapshotData.drawdownMaxInPercentage = drawdownTracker.GetMaxInPercentage();

	snapshotData.quality = quality.quality;
	snapshotData.qualityReason = quality.reason;

	double previousNav = navTracker.GetPreviousDay();
	double dailyPerformance = navTracker.GetDailyPerformance();

	if (ArraySize(snapshotData.nav) > 1 && previousNav != 0.0) {
		snapshotData.dailyPerformance = dailyPerformance / previousNav;
	} else {
		snapshotData.dailyPerformance = 0.0;
	}

	return snapshotData;
}

#endif
