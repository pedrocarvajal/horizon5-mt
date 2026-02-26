#ifndef __SR_REPORT_OF_ALLOCATOR_ANALYSIS_MQH__
#define __SR_REPORT_OF_ALLOCATOR_ANALYSIS_MQH__

#include "../../helpers/HGetReportsPath.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"

class SRReportOfAllocatorAnalysis {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *analysisCollection;

	string reportsDir;
	string reportName;
	string reportSymbol;

	void initialize(string directory, string name) {
		logger.SetPrefix("AllocatorAnalysisReporter");
		reportsDir = directory;
		reportName = name;

		database.Initialize(directory, true);
		analysisCollection = database.Collection(name);
		analysisCollection.SetAutoFlush(false);
	}

public:
	SRReportOfAllocatorAnalysis(string symbol, string customReportName) {
		reportSymbol = symbol;
		initialize(GetReportsPath(symbol), customReportName);
	}

	void AddDayRecord(
		int dayIndex,
		double rawReturn,
		double rawVolatility,
		double rawDrawdown,
		double normalizedReturn,
		double normalizedVolatility,
		double normalizedDrawdown,
		double averageNeighborDistance,
		int neighborCount,
		int strategyCount,
		string &strategyPrefixes[],
		double &scores[],
		double &forwardPerformances[],
		double &scoreStds[]
	) {
		JSON::Object *record = new JSON::Object();
		record.setProperty("symbol", reportSymbol);
		record.setProperty("day", dayIndex);
		record.setProperty("raw_return", rawReturn);
		record.setProperty("raw_volatility", rawVolatility);
		record.setProperty("raw_drawdown", rawDrawdown);
		record.setProperty("z_return", normalizedReturn);
		record.setProperty("z_volatility", normalizedVolatility);
		record.setProperty("z_drawdown", normalizedDrawdown);
		record.setProperty("avg_neighbor_distance", averageNeighborDistance);
		record.setProperty("neighbor_count", neighborCount);

		JSON::Array *prefixesArray = new JSON::Array();

		for (int i = 0; i < strategyCount; i++) {
			prefixesArray.add(strategyPrefixes[i]);
		}

		record.setProperty("strategy_prefixes", prefixesArray);

		JSON::Array *scoresArray = new JSON::Array();

		for (int i = 0; i < ArraySize(scores); i++) {
			scoresArray.add(scores[i]);
		}

		record.setProperty("scores", scoresArray);

		JSON::Array *forwardArray = new JSON::Array();

		for (int i = 0; i < ArraySize(forwardPerformances); i++) {
			forwardArray.add(forwardPerformances[i]);
		}

		record.setProperty("forward_performances", forwardArray);

		JSON::Array *stdsArray = new JSON::Array();

		for (int i = 0; i < ArraySize(scoreStds); i++) {
			stdsArray.add(scoreStds[i]);
		}

		record.setProperty("score_stds", stdsArray);

		analysisCollection.InsertOne(record);
		delete record;
	}

	void Export() {
		analysisCollection.Flush();

		logger.Info(StringFormat(
			"Allocator analysis saved - %s.json with %d records",
			reportName,
			analysisCollection.Count()
		));
	}

	int GetRecordCount() {
		return analysisCollection.Count();
	}
};

#endif
