#ifndef __SE_REPORT_OF_SNAPSHOT_HISTORY_MQH__
#define __SE_REPORT_OF_SNAPSHOT_HISTORY_MQH__

#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SSOrderHistory.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../SEDateTime/structs/SDateTime.mqh"
#include "../SEDb/SEDb.mqh"

extern SEDateTime dtime;

class SEReportOfSnapshotHistory {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *snapshotsCollection;

	string reportsDir;
	string reportName;
	bool useCommonFiles;

	void initialize(string directory, string name, bool useCommon) {
		logger.SetPrefix("SnapshotHistoryReporter");
		reportsDir = directory;
		reportName = name;
		useCommonFiles = useCommon;

		database.Initialize(directory, useCommon);
		snapshotsCollection = database.Collection(name);
		snapshotsCollection.SetAutoFlush(false);
	}

	JSON::Object *SnapshotToJson(const SSStatisticsSnapshot &snapshot) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("timestamp", (long)snapshot.timestamp);
		obj.setProperty("id", snapshot.id);

		double lastNav = (ArraySize(snapshot.nav) > 0) ? snapshot.nav[ArraySize(snapshot.nav) - 1] : 0.0;
		double lastPerformance = (ArraySize(snapshot.performance) > 0) ? snapshot.performance[ArraySize(snapshot.performance) - 1] : 0.0;
		obj.setProperty("nav", lastNav);
		obj.setProperty("performance", lastPerformance);

		obj.setProperty("nav_peak", snapshot.navPeak);
		obj.setProperty("drawdown_max_in_dollars", snapshot.drawdownMaxInDollars);
		obj.setProperty("drawdown_max_in_percentage", snapshot.drawdownMaxInPercentage);
		obj.setProperty("winning_orders", snapshot.winningOrders);
		obj.setProperty("winning_orders_performance", snapshot.winningOrdersPerformance);
		obj.setProperty("losing_orders", snapshot.losingOrders);
		obj.setProperty("losing_orders_performance", snapshot.losingOrdersPerformance);
		obj.setProperty("max_loss", snapshot.maxLoss);

		obj.setProperty("r_squared", snapshot.rSquared);
		obj.setProperty("sharpe_ratio", snapshot.sharpeRatio);
		obj.setProperty("risk_reward_ratio", snapshot.riskRewardRatio);
		obj.setProperty("win_rate", snapshot.winRate);
		obj.setProperty("recovery_factor", snapshot.recoveryFactor);
		obj.setProperty("cagr", snapshot.cagr);
		obj.setProperty("stability", snapshot.stability);
		obj.setProperty("stability_sq3", snapshot.stabilitySQ3);

		obj.setProperty("quality", snapshot.quality);
		obj.setProperty("quality_reason", snapshot.qualityReason);

		obj.setProperty("max_exposure_in_lots", snapshot.maxExposureInLots);
		obj.setProperty("max_exposure_in_percentage", snapshot.maxExposureInPercentage);

		return obj;
	}

public:
	SEReportOfSnapshotHistory() {
		initialize(
			StringFormat("/Reports/%s/%lld", _Symbol, (long)dtime.Timestamp()),
			"Snapshots",
			false
		);
	}

	SEReportOfSnapshotHistory(string customDir, bool useCommonFolder = false, string customReportName = "Snapshots") {
		initialize(
			customDir,
			customReportName,
			useCommonFolder
		);
	}

	void AddSnapshot(const SSStatisticsSnapshot &snapshot) {
		JSON::Object *json = SnapshotToJson(snapshot);
		snapshotsCollection.InsertOne(json);

		delete json;
	}

	void Export() {
		logger.debug(StringFormat(
			"Exporting %d snapshots to %s\\%s.json",
			snapshotsCollection.Count(), GetCurrentReportsPath(), reportName
		));

		snapshotsCollection.Flush();

		logger.info(StringFormat(
			"Snapshot history saved - %s.json with %d snapshots",
			reportName,
			snapshotsCollection.Count()
		));
	}

	int GetSnapshotCount() {
		return snapshotsCollection.Count();
	}

	string GetCurrentReportsPath() {
		string pathSeparator = "\\";
		string convertedDir = reportsDir;
		StringReplace(convertedDir, "/", pathSeparator);

		if (useCommonFiles) {
			return StringFormat("%s%sFiles%s",
				TerminalInfoString(TERMINAL_COMMONDATA_PATH),
				pathSeparator,
				convertedDir
			);
		} else {
			return StringFormat("%s%sMQL5%sFiles%s",
				TerminalInfoString(TERMINAL_DATA_PATH),
				pathSeparator,
				pathSeparator,
				convertedDir
			);
		}
	}
};

#endif
