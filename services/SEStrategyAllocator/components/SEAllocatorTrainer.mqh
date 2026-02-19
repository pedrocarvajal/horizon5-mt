#ifndef __SE_ALLOCATOR_TRAINER_MQH__
#define __SE_ALLOCATOR_TRAINER_MQH__

#include "SEAllocatorConstants.mqh"
#include "../../SEDb/SEDb.mqh"
#include "../../SELogger/SELogger.mqh"

class SEAllocatorTrainer {
private:
	SELogger * logger;
	int strategyCount;
	double strategyPerformanceHistory[];

	int performanceIndex(int day, int strategy) {
		return day * strategyCount + strategy;
	}

public:
	SEAllocatorTrainer(SELogger * parentLogger) {
		logger = parentLogger;
		strategyCount = 0;
	}

	void CollectPerformance(int currentDay, int strategies, double &dailyPerformances[]) {
		strategyCount = strategies;

		int newPerfSize = (currentDay + 1) * strategyCount;
		ArrayResize(strategyPerformanceHistory, newPerfSize);

		for (int s = 0; s < strategyCount; s++) {
			double performance = (s < ArraySize(dailyPerformances))
				? dailyPerformances[s]
				: 0.0;

			strategyPerformanceHistory[performanceIndex(currentDay, s)] = performance;
		}
	}

	bool SaveModel(
		string databasePath,
		string collectionName,
		int rollingWindowDays,
		int normalizationWindow,
		int kNeighbors,
		int maxActiveStrategies,
		double scoreThreshold,
		int forwardWindow,
		int maxCandidateCount,
		int totalStrategyCount,
		string &strategyPrefixes[],
		int totalDays,
		int normalizedCount,
		double &featureHistory[],
		double &normalizedFeatures[]
	) {
		SEDb database;
		database.Initialize(databasePath, true);

		SEDbCollection *collection = database.Collection(collectionName);

		if (collection == NULL) {
			logger.Error(StringFormat("Failed to open collection %s/%s", databasePath, collectionName));
			return false;
		}

		if (normalizedCount < 1) {
			logger.Error(StringFormat(
				"Cannot save model: no normalized features (totalDays=%d, normalizationWindow=%d). Training backtest must be longer than normalization window.",
				totalDays,
				normalizationWindow
			));
			return false;
		}

		if (maxCandidateCount < 1) {
			logger.Error(StringFormat(
				"Cannot save model: no KNN candidates (maxCandidateCount=%d). Training backtest must be longer than normalization window + forward window.",
				maxCandidateCount
			));
			return false;
		}

		collection.SetAutoFlush(false);
		collection.DeleteOne("type", "allocator_model");

		JSON::Object *model = new JSON::Object();
		model.setProperty("type", "allocator_model");
		model.setProperty("version", 1);
		model.setProperty("rollingWindowDays", rollingWindowDays);
		model.setProperty("normalizationWindow", normalizationWindow);
		model.setProperty("kNeighbors", kNeighbors);
		model.setProperty("maxActiveStrategies", maxActiveStrategies);
		model.setProperty("scoreThreshold", scoreThreshold);
		model.setProperty("forwardWindow", forwardWindow);
		model.setProperty("maxCandidateCount", maxCandidateCount);
		model.setProperty("strategyCount", totalStrategyCount);
		model.setProperty("totalDays", totalDays);
		model.setProperty("normalizedCount", normalizedCount);

		JSON::Array *prefixes = new JSON::Array();

		for (int i = 0; i < totalStrategyCount; i++) {
			prefixes.add(strategyPrefixes[i]);
		}

		model.setProperty("strategyPrefixes", prefixes);

		JSON::Array *features = new JSON::Array();

		for (int i = 0; i < ArraySize(featureHistory); i++) {
			features.add(featureHistory[i]);
		}

		model.setProperty("featureHistory", features);

		JSON::Array *performance = new JSON::Array();

		for (int i = 0; i < ArraySize(strategyPerformanceHistory); i++) {
			performance.add(strategyPerformanceHistory[i]);
		}

		model.setProperty("strategyPerformanceHistory", performance);

		JSON::Array *normalized = new JSON::Array();

		for (int i = 0; i < ArraySize(normalizedFeatures); i++) {
			normalized.add(normalizedFeatures[i]);
		}

		model.setProperty("normalizedFeatures", normalized);

		collection.InsertOne(model);
		bool flushed = collection.Flush();

		delete model;

		if (!flushed) {
			logger.Error(StringFormat("Model flush failed: %s/%s", databasePath, collectionName));
			return false;
		}

		logger.Info(StringFormat(
			"Model saved: %s/%s | days=%d normalized=%d strategies=%d",
			databasePath,
			collectionName,
			totalDays,
			normalizedCount,
			totalStrategyCount
		));

		return true;
	}
};

#endif
