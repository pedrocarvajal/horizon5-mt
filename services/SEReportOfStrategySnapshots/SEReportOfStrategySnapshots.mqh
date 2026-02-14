#ifndef __SE_REPORT_OF_STRATEGY_SNAPSHOTS_MQH__
#define __SE_REPORT_OF_STRATEGY_SNAPSHOTS_MQH__

#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SSOrderHistory.mqh"
#include "../../helpers/HGetReportsPath.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"

class SEReportOfStrategySnapshots {
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
	SEReportOfStrategySnapshots(string symbol, string name, string prefix, string customReportName) {
		reportSymbol = symbol;
		strategyName = name;
		strategyPrefix = prefix;
		initialize(GetReportsPath(symbol), customReportName);
	}

	void AddSnapshot(const SSStatisticsSnapshot &snapshot) {
		JSON::Object *json = snapshotToJson(snapshot);
		snapshotsCollection.InsertOne(json);

		delete json;
	}

	void Export() {
		logger.Debug(StringFormat(
			"Exporting %d snapshots to %s\\%s.json",
			snapshotsCollection.Count(), GetCurrentReportsPath(), reportName
		));

		snapshotsCollection.Flush();

		logger.Info(StringFormat(
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

		return StringFormat("%s%sFiles%s",
			TerminalInfoString(TERMINAL_COMMONDATA_PATH),
			pathSeparator,
			convertedDir
		);
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

		obj.setProperty("daily_performance", snapshot.dailyPerformance);

		return obj;
	}
};

#endif
