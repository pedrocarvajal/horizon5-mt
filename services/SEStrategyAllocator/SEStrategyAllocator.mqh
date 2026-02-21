#ifndef __SE_STRATEGY_ALLOCATOR_MQH__
#define __SE_STRATEGY_ALLOCATOR_MQH__

#include "../../enums/EAllocatorMode.mqh"
#include "../SELogger/SELogger.mqh"
#include "components/SEAllocatorConstants.mqh"
#include "components/SEAllocatorTrainer.mqh"
#include "components/SEAllocatorInference.mqh"

class SEStrategyAllocator {
private:
	SELogger logger;
	ENUM_ALLOCATOR_MODE mode;

	int rollingWindowDays;
	int normalizationWindow;
	int kNeighbors;
	int maxActiveStrategies;
	double scoreThreshold;
	int forwardWindow;

	int strategyCount;
	string strategyPrefixes[];

	int totalDays;
	double featureHistory[];

	int normalizedCount;
	double normalizedFeatures[];

	int maxCandidateCount;
	string activeStrategies[];

	SEAllocatorTrainer *trainer;
	SEAllocatorInference *inference;

	int featureIndex(int day, int feature) {
		return day * ALLOCATOR_FEATURE_COUNT + feature;
	}

	void normalizeLatestFeatures() {
		if (totalDays < normalizationWindow + 1) {
			return;
		}

		int windowStart = totalDays - normalizationWindow - 1;

		double normalizedDay[];
		ArrayResize(normalizedDay, ALLOCATOR_FEATURE_COUNT);

		double means[];
		double stdevs[];
		ArrayResize(means, ALLOCATOR_FEATURE_COUNT);
		ArrayResize(stdevs, ALLOCATOR_FEATURE_COUNT);

		for (int f = 0; f < ALLOCATOR_FEATURE_COUNT; f++) {
			double sum = 0.0;
			int count = normalizationWindow + 1;

			for (int d = windowStart; d < totalDays; d++) {
				sum += featureHistory[featureIndex(d, f)];
			}

			double mean = sum / count;
			means[f] = mean;

			double sumSquaredDiff = 0.0;

			for (int d = windowStart; d < totalDays; d++) {
				double diff = featureHistory[featureIndex(d, f)] - mean;
				sumSquaredDiff += diff * diff;
			}

			double stdev = (count > 1) ? MathSqrt(sumSquaredDiff / (count - 1)) : 0.0;
			stdevs[f] = stdev;
			double currentValue = featureHistory[featureIndex(totalDays - 1, f)];

			normalizedDay[f] = (stdev > 0.0)
				? (currentValue - mean) / stdev
				: 0.0;
		}

		int newSize = (normalizedCount + 1) * ALLOCATOR_FEATURE_COUNT;
		ArrayResize(normalizedFeatures, newSize);

		for (int f = 0; f < ALLOCATOR_FEATURE_COUNT; f++) {
			normalizedFeatures[featureIndex(normalizedCount, f)] = normalizedDay[f];
		}

		normalizedCount++;

		logger.Debug(StringFormat(
			"Norm window=[%d..%d] | mean=[%.4f,%.4f,%.4f] std=[%.4f,%.4f,%.4f] | z=[%.4f,%.4f,%.4f]",
			windowStart,
			totalDays - 1,
			means[0], means[1], means[2],
			stdevs[0], stdevs[1], stdevs[2],
			normalizedDay[0], normalizedDay[1], normalizedDay[2]
		));
	}

public:
	SEStrategyAllocator(
		ENUM_ALLOCATOR_MODE allocatorMode,
		int rollingWindow,
		int normWindow,
		int neighbors,
		int maxActive,
		double threshold,
		int forward
	) {
		logger.SetPrefix("SEStrategyAllocator");

		mode = allocatorMode;
		rollingWindowDays = rollingWindow;
		normalizationWindow = normWindow;
		kNeighbors = neighbors;
		maxActiveStrategies = maxActive;
		scoreThreshold = threshold;
		forwardWindow = forward;

		totalDays = 0;
		normalizedCount = 0;
		strategyCount = 0;
		maxCandidateCount = 0;

		trainer = NULL;
		inference = NULL;

		if (mode == ALLOCATOR_MODE_TRAIN) {
			trainer = new SEAllocatorTrainer(GetPointer(logger));
		} else {
			inference = new SEAllocatorInference(GetPointer(logger));
		}

		logger.Info(StringFormat(
			"Initialized | mode=%s rolling=%d norm=%d k=%d maxActive=%d threshold=%.4f forward=%d",
			mode == ALLOCATOR_MODE_TRAIN ? "TRAIN" : "INFERENCE",
			rollingWindowDays,
			normalizationWindow,
			kNeighbors,
			maxActiveStrategies,
			scoreThreshold,
			forwardWindow
		));
	}

	~SEStrategyAllocator() {
		if (CheckPointer(trainer) == POINTER_DYNAMIC) {
			delete trainer;
		}

		if (CheckPointer(inference) == POINTER_DYNAMIC) {
			delete inference;
		}
	}

	void SetDebugLevel(ENUM_DEBUG_LEVEL level) {
		logger.SetDebugLevel(level);
	}

	void GetLogEntries(string &result[]) {
		logger.GetEntries(result);
	}

	void GetActiveStrategies(string &result[]) {
		int size = ArraySize(activeStrategies);
		ArrayResize(result, size);
		ArrayCopy(result, activeStrategies, 0, 0, size);
	}

	bool IsWarmupComplete() {
		return mode != ALLOCATOR_MODE_TRAIN;
	}

	void OnStartDay(
		double rollingReturn,
		double rollingVolatility,
		double rollingDrawdown,
		double &dailyPerformances[]
	) {
		int newFeatureSize = (totalDays + 1) * ALLOCATOR_FEATURE_COUNT;
		ArrayResize(featureHistory, newFeatureSize);

		featureHistory[featureIndex(totalDays, 0)] = rollingReturn;
		featureHistory[featureIndex(totalDays, 1)] = rollingVolatility;
		featureHistory[featureIndex(totalDays, 2)] = rollingDrawdown;

		if (mode == ALLOCATOR_MODE_TRAIN) {
			trainer.CollectPerformance(totalDays, strategyCount, dailyPerformances);
		}

		totalDays++;

		logger.Debug(StringFormat(
			"Day %d | Features: return=%.4f vol=%.4f dd=%.4f",
			totalDays,
			rollingReturn,
			rollingVolatility,
			rollingDrawdown
		));

		if (totalDays <= normalizationWindow) {
			return;
		}

		normalizeLatestFeatures();

		if (mode == ALLOCATOR_MODE_TRAIN) {
			return;
		}

		logger.Debug(StringFormat(
			"Inference day %d | raw=[%.4f,%.4f,%.4f] | normIdx=%d candidateRange=[0..%d]",
			totalDays,
			featureHistory[featureIndex(totalDays - 1, 0)],
			featureHistory[featureIndex(totalDays - 1, 1)],
			featureHistory[featureIndex(totalDays - 1, 2)],
			normalizedCount - 1,
			maxCandidateCount - 1
		));

		inference.ComputeActivations(normalizedFeatures, normalizedCount, activeStrategies);
	}

	void RegisterStrategy(string prefix) {
		ArrayResize(strategyPrefixes, strategyCount + 1);
		strategyPrefixes[strategyCount] = prefix;
		strategyCount++;

		logger.Debug(StringFormat(
			"Registered strategy: %s (total: %d)",
			prefix,
			strategyCount
		));
	}

	bool SaveModel(string databasePath, string collectionName) {
		if (mode != ALLOCATOR_MODE_TRAIN) {
			logger.Error("SaveModel called in non-train mode");
			return false;
		}

		maxCandidateCount = totalDays - normalizationWindow - forwardWindow;

		return trainer.SaveModel(
			databasePath,
			collectionName,
			rollingWindowDays,
			normalizationWindow,
			kNeighbors,
			maxActiveStrategies,
			scoreThreshold,
			forwardWindow,
			maxCandidateCount,
			strategyCount,
			strategyPrefixes,
			totalDays,
			normalizedCount,
			featureHistory,
			normalizedFeatures
		);
	}

	void RunAnalysis(string symbol) {
		if (mode != ALLOCATOR_MODE_TRAIN) {
			logger.Error("RunAnalysis called in non-train mode");
			return;
		}

		maxCandidateCount = totalDays - normalizationWindow - forwardWindow;

		trainer.RunAnalysis(
			symbol,
			kNeighbors,
			normalizationWindow,
			maxCandidateCount,
			strategyCount,
			strategyPrefixes,
			totalDays,
			normalizedCount,
			featureHistory,
			normalizedFeatures
		);
	}

	bool LoadModel(string databasePath, string collectionName) {
		if (mode != ALLOCATOR_MODE_INFERENCE) {
			logger.Error("LoadModel called in non-inference mode");
			return false;
		}

		bool result = inference.LoadModel(
			databasePath,
			collectionName,
			rollingWindowDays,
			normalizationWindow,
			kNeighbors,
			maxActiveStrategies,
			scoreThreshold,
			forwardWindow,
			maxCandidateCount,
			strategyCount,
			strategyPrefixes,
			totalDays,
			normalizedCount,
			featureHistory,
			normalizedFeatures
		);

		if (result) {
			logger.Info(StringFormat(
				"Model overrides: rolling=%d norm=%d forward=%d | User params: k=%d maxActive=%d threshold=%.4f",
				rollingWindowDays,
				normalizationWindow,
				forwardWindow,
				kNeighbors,
				maxActiveStrategies,
				scoreThreshold
			));
		}

		return result;
	}
};

#endif
