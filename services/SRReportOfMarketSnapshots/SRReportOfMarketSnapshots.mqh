#ifndef __SR_REPORT_OF_MARKET_SNAPSHOTS_MQH__
#define __SR_REPORT_OF_MARKET_SNAPSHOTS_MQH__

#include "../../structs/SSMarketSnapshot.mqh"

#include "../../helpers/HGetReportsPath.mqh"

#include "../SELogger/SELogger.mqh"

#include "../SEDb/SEDb.mqh"

class SRReportOfMarketSnapshots {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *marketCollection;

	string reportsDir;
	string reportName;
	string reportSymbol;

public:
	SRReportOfMarketSnapshots(string symbol, string customReportName) {
		reportSymbol = symbol;
		initialize(REPORTS_PATH, customReportName);
	}

	void AddSnapshot(const SSMarketSnapshot &snapshot) {
		JSON::Object *json = snapshotToJson(snapshot);
		marketCollection.InsertOne(json);

		delete json;
	}

	void Export() {
		marketCollection.Flush();

		logger.Info(
			LOG_CODE_STATS_EXPORT_FAILED,
			StringFormat(
				"Market history saved - %s.json with %d snapshots",
				reportName,
				marketCollection.Count()
		));
	}

	int GetSnapshotCount() {
		return marketCollection.Count();
	}

private:
	void initialize(string directory, string name) {
		logger.SetPrefix("MarketSnapshotsReporter");
		reportsDir = directory;
		reportName = name;

		database.Initialize(directory, true);
		marketCollection = database.Collection(name);
		marketCollection.SetAutoFlush(false);
	}

	JSON::Object *snapshotToJson(const SSMarketSnapshot &snapshot) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("timestamp", (long)snapshot.timestamp);
		obj.setProperty("symbol", reportSymbol);
		obj.setProperty("level", "market");
		obj.setProperty("bid", snapshot.bid);
		obj.setProperty("ask", snapshot.ask);
		obj.setProperty("spread", snapshot.spread);
		obj.setProperty("rolling_performance", snapshot.rollingPerformance);
		obj.setProperty("rolling_drawdown", snapshot.rollingDrawdown);
		obj.setProperty("rolling_volatility", snapshot.rollingVolatility);

		return obj;
	}
};

#endif
