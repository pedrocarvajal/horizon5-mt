#ifndef __SR_REPORT_OF_STRATEGY_SNAPSHOTS_MQH__
#define __SR_REPORT_OF_STRATEGY_SNAPSHOTS_MQH__

#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SSOrderHistory.mqh"

#include "../../helpers/HGetReportsPath.mqh"

#include "../SELogger/SELogger.mqh"

#include "../SEDb/SEDb.mqh"

class SRReportOfStrategySnapshots {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *snapshotsCollection;

	string reportsDir;
	string reportName;
	string reportSymbol;
	string strategyName;
	string strategyPrefix;

public:
	SRReportOfStrategySnapshots(string symbol, string name, string prefix, string customReportName) {
		reportSymbol = symbol;
		strategyName = name;
		strategyPrefix = prefix;
		initialize(REPORTS_PATH, customReportName);
	}

	void AddSnapshot(const SSStatisticsSnapshot &snapshot) {
		JSON::Object *json = snapshotToJson(snapshot);
		snapshotsCollection.InsertOne(json);

		delete json;
	}

	void Export() {
		snapshotsCollection.Flush();

		logger.Info(
			LOG_CODE_STATS_EXPORT_FAILED,
			StringFormat(
				"Snapshot history saved - %s.json with %d snapshots",
				reportName,
				snapshotsCollection.Count()
		));
	}

	int GetSnapshotCount() {
		return snapshotsCollection.Count();
	}

private:
	void initialize(string directory, string name) {
		logger.SetPrefix("StrategySnapshotsReporter");
		reportsDir = directory;
		reportName = name;

		database.Initialize(directory, true);
		snapshotsCollection = database.Collection(name);
		snapshotsCollection.SetAutoFlush(false);
	}

	JSON::Object *snapshotToJson(const SSStatisticsSnapshot &snapshot) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("timestamp", (long)snapshot.timestamp);
		obj.setProperty("id", snapshot.id);
		obj.setProperty("symbol", reportSymbol);
		obj.setProperty("strategy_name", strategyName);
		obj.setProperty("strategy_prefix", strategyPrefix);
		obj.setProperty("level", "strategy");

		double lastNav = (ArraySize(snapshot.nav) > 0) ? snapshot.nav[ArraySize(snapshot.nav) - 1] : 0.0;
		double lastPerformance = (ArraySize(snapshot.performance) > 0) ? snapshot.performance[ArraySize(snapshot.performance) - 1] : 0.0;
		obj.setProperty("nav", lastNav);
		obj.setProperty("performance", lastPerformance);

		obj.setProperty("nav_peak", snapshot.navPeak);
		obj.setProperty("drawdown_max_in_dollars", snapshot.drawdownMaxInDollars);
		obj.setProperty("drawdown_max_in_percentage", snapshot.drawdownMaxInPercentage);

		obj.setProperty("quality", snapshot.quality);
		obj.setProperty("quality_reason", snapshot.qualityReason);

		obj.setProperty("daily_performance", snapshot.dailyPerformance);

		return obj;
	}
};

#endif
