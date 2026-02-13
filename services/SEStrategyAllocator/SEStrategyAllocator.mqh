#ifndef __SE_STRATEGY_ALLOCATOR_MQH__
#define __SE_STRATEGY_ALLOCATOR_MQH__

#include "../../enums/EAllocatorMode.mqh"
#include "../SEDb/SEDb.mqh"
#include "../SELogger/SELogger.mqh"

#define ALLOCATOR_FEATURE_COUNT 3

class SEStrategyAllocator {
private:
	SELogger logger;
	ENUM_ALLOCATOR_MODE mode;

	int rollingWindowDays;
	int normalizationWindow;
	int kNeighbors;
	int maxActiveStrategies;
	double epsilon;
	double scoreThreshold;
	int forwardWindow;
	int trainingDays;

	int strategyCount;
	string strategyPrefixes[];

	int totalDays;
	double featureHistory[];
	double strategyPerformanceHistory[];

	int normalizedCount;
	double normalizedFeatures[];

	int maxCandidateCount;
	string activeStrategies[];

	int featureIndex(int day, int feature) {
		return day * ALLOCATOR_FEATURE_COUNT + feature;
	}

	int performanceIndex(int day, int strategy) {
		return day * strategyCount + strategy;
	}

	int normalizedIndex(int day, int feature) {
		return day * ALLOCATOR_FEATURE_COUNT + feature;
	}

	int findStrategyIndex(string prefix) {
		for (int i = 0; i < strategyCount; i++) {
			if (strategyPrefixes[i] == prefix)
				return i;
		}

		return -1;
	}

	void normalizeLatestFeatures() {
		if (totalDays < normalizationWindow + 1)
			return;

		int windowStart = totalDays - normalizationWindow - 1;

		double normalizedDay[];
		ArrayResize(normalizedDay, ALLOCATOR_FEATURE_COUNT);

		for (int f = 0; f < ALLOCATOR_FEATURE_COUNT; f++) {
			double sum = 0.0;
			int count = normalizationWindow + 1;

			for (int d = windowStart; d < totalDays; d++) {
				sum += featureHistory[featureIndex(d, f)];
			}

			double mean = sum / count;

			double sumSquaredDiff = 0.0;

			for (int d = windowStart; d < totalDays; d++) {
				double diff = featureHistory[featureIndex(d, f)] - mean;
				sumSquaredDiff += diff * diff;
			}

			double stdev = (count > 1) ? MathSqrt(sumSquaredDiff / (count - 1)) : 0.0;
			double currentValue = featureHistory[featureIndex(totalDays - 1, f)];

			normalizedDay[f] = (stdev > 0.0)
				? (currentValue - mean) / stdev
				: 0.0;
		}

		int newSize = (normalizedCount + 1) * ALLOCATOR_FEATURE_COUNT;
		ArrayResize(normalizedFeatures, newSize);

		for (int f = 0; f < ALLOCATOR_FEATURE_COUNT; f++) {
			normalizedFeatures[normalizedIndex(normalizedCount, f)] = normalizedDay[f];
		}

		normalizedCount++;

		logger.debug(StringFormat(
			"Normalized: z_return=%.4f z_vol=%.4f z_dd=%.4f",
			normalizedDay[0],
			normalizedDay[1],
			normalizedDay[2]
		));
	}

	double euclideanDistance(int indexA, int indexB) {
		double sum = 0.0;

		for (int f = 0; f < ALLOCATOR_FEATURE_COUNT; f++) {
			double diff = normalizedFeatures[normalizedIndex(indexA, f)]
				      - normalizedFeatures[normalizedIndex(indexB, f)];
			sum += diff * diff;
		}

		return MathSqrt(sum);
	}

	void computeActivations() {
		int todayNormIndex = normalizedCount - 1;
		int candidateCount = maxCandidateCount;

		if (candidateCount < 1) {
			logger.debug("KNN skipped: no training candidates available");
			return;
		}

		double distances[];
		int distanceIndices[];
		ArrayResize(distances, candidateCount);
		ArrayResize(distanceIndices, candidateCount);

		for (int p = 0; p < candidateCount; p++) {
			distances[p] = euclideanDistance(todayNormIndex, p);
			distanceIndices[p] = p;
		}

		sortDistances(distances, distanceIndices, candidateCount);

		int neighborsCount = MathMin(kNeighbors, candidateCount);

		double weightSum = 0.0;

		for (int n = 0; n < neighborsCount; n++) {
			weightSum += 1.0 / (distances[n] + epsilon);
		}

		logger.debug(StringFormat(
			"KNN: %d neighbors from %d candidates, distances [%.4f..%.4f]",
			neighborsCount,
			candidateCount,
			distances[0],
			distances[neighborsCount - 1]
		));

		double strategyScores[];
		ArrayResize(strategyScores, strategyCount);

		string scoresLog = "Scores: ";

		for (int s = 0; s < strategyCount; s++) {
			double weightedSum = 0.0;

			for (int n = 0; n < neighborsCount; n++) {
				int neighborNormIndex = distanceIndices[n];
				int originalDayIndex = neighborNormIndex + normalizationWindow;
				double weight = 1.0 / (distances[n] + epsilon);

				double forwardPerformanceSum = 0.0;
				int forwardCount = 0;
				int forwardEnd = MathMin(originalDayIndex + forwardWindow, trainingDays);

				for (int fw = originalDayIndex; fw < forwardEnd; fw++) {
					forwardPerformanceSum += strategyPerformanceHistory[performanceIndex(fw, s)];
					forwardCount++;
				}

				double averageForwardPerformance = (forwardCount > 0)
					? forwardPerformanceSum / forwardCount
					: 0.0;

				weightedSum += weight * averageForwardPerformance;
			}

			strategyScores[s] = weightedSum / weightSum;

			if (s > 0)
				scoresLog += " ";

			scoresLog += StringFormat("%s=%.6f", strategyPrefixes[s], strategyScores[s]);
		}

		logger.debug(scoresLog);

		double sortedScores[];
		int sortedIndices[];
		ArrayResize(sortedScores, strategyCount);
		ArrayResize(sortedIndices, strategyCount);

		for (int s = 0; s < strategyCount; s++) {
			sortedScores[s] = strategyScores[s];
			sortedIndices[s] = s;
		}

		sortScoresDescending(sortedScores, sortedIndices, strategyCount);

		ArrayResize(activeStrategies, 0);
		int activeCount = 0;

		for (int s = 0; s < strategyCount && activeCount < maxActiveStrategies; s++) {
			if (sortedScores[s] > scoreThreshold) {
				ArrayResize(activeStrategies, activeCount + 1);
				activeStrategies[activeCount] = strategyPrefixes[sortedIndices[s]];
				activeCount++;
			}
		}

		string activeLog = StringFormat(
			"Active (%d/%d): ",
			activeCount,
			maxActiveStrategies
		);

		for (int i = 0; i < activeCount; i++) {
			if (i > 0)
				activeLog += ", ";

			activeLog += activeStrategies[i];
		}

		logger.info(activeLog);
	}

	void sortDistances(double &dist[], int &indices[], int count) {
		for (int i = 0; i < count - 1; i++) {
			for (int j = i + 1; j < count; j++) {
				if (dist[j] < dist[i]) {
					double tempDist = dist[i];
					dist[i] = dist[j];
					dist[j] = tempDist;

					int tempIdx = indices[i];
					indices[i] = indices[j];
					indices[j] = tempIdx;
				}
			}
		}
	}

	void sortScoresDescending(double &scores[], int &indices[], int count) {
		for (int i = 0; i < count - 1; i++) {
			for (int j = i + 1; j < count; j++) {
				if (scores[j] > scores[i]) {
					double tempScore = scores[i];
					scores[i] = scores[j];
					scores[j] = tempScore;

					int tempIdx = indices[i];
					indices[i] = indices[j];
					indices[j] = tempIdx;
				}
			}
		}
	}

public:
	SEStrategyAllocator(
		ENUM_ALLOCATOR_MODE allocatorMode,
		int rollingWindow,
		int normWindow,
		int neighbors,
		int maxActive,
		double threshold,
		int forward,
		int training
	) {
		logger.SetPrefix("SEStrategyAllocator");

		mode = allocatorMode;
		rollingWindowDays = rollingWindow;
		normalizationWindow = normWindow;
		kNeighbors = neighbors;
		maxActiveStrategies = maxActive;
		epsilon = 0.0001;
		scoreThreshold = threshold;
		forwardWindow = forward;
		trainingDays = training;

		totalDays = 0;
		normalizedCount = 0;
		strategyCount = 0;
		maxCandidateCount = trainingDays - normalizationWindow - forwardWindow;

		logger.info(StringFormat(
			"Initialized | mode=%s rolling=%d norm=%d k=%d maxActive=%d threshold=%.4f forward=%d training=%d candidates=%d",
			mode == ALLOCATOR_MODE_TRAIN ? "TRAIN" : "INFERENCE",
			rollingWindowDays,
			normalizationWindow,
			kNeighbors,
			maxActiveStrategies,
			scoreThreshold,
			forwardWindow,
			trainingDays,
			maxCandidateCount
		));
	}

	void GetActiveStrategies(string &result[]) {
		ArrayResize(result, ArraySize(activeStrategies));

		for (int i = 0; i < ArraySize(activeStrategies); i++) {
			result[i] = activeStrategies[i];
		}
	}

	bool IsWarmupComplete() {
		if (mode == ALLOCATOR_MODE_TRAIN)
			return false;

		return totalDays > trainingDays;
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

		if (mode == ALLOCATOR_MODE_TRAIN && totalDays < trainingDays) {
			int newPerfSize = (totalDays + 1) * strategyCount;
			ArrayResize(strategyPerformanceHistory, newPerfSize);

			for (int s = 0; s < strategyCount; s++) {
				double performance = (s < ArraySize(dailyPerformances))
					? dailyPerformances[s]
					: 0.0;

				strategyPerformanceHistory[performanceIndex(totalDays, s)] = performance;
			}
		}

		totalDays++;

		logger.debug(StringFormat(
			"Day %d | Features: return=%.4f vol=%.4f dd=%.4f",
			totalDays,
			rollingReturn,
			rollingVolatility,
			rollingDrawdown
		));

		if (totalDays <= normalizationWindow) {
			logger.debug(StringFormat(
				"Collecting features: %d/%d days (%.1f%%)",
				totalDays,
				trainingDays,
				(double)totalDays / trainingDays * 100.0
			));

			return;
		}

		normalizeLatestFeatures();

		if (totalDays <= trainingDays) {
			logger.debug(StringFormat(
				"Training: %d/%d days (%.1f%%)",
				totalDays,
				trainingDays,
				(double)totalDays / trainingDays * 100.0
			));

			return;
		}

		if (totalDays == trainingDays + 1) {
			logger.info(StringFormat(
				"Training complete | %d days | %d candidates | k=%d",
				trainingDays,
				maxCandidateCount,
				kNeighbors
			));
		}

		if (mode == ALLOCATOR_MODE_TRAIN)
			return;

		computeActivations();
	}

	void RegisterStrategy(string prefix) {
		ArrayResize(strategyPrefixes, strategyCount + 1);
		strategyPrefixes[strategyCount] = prefix;
		strategyCount++;

		logger.debug(StringFormat(
			"Registered strategy: %s (total: %d)",
			prefix,
			strategyCount
		));
	}

	bool SaveModel(string databasePath, string collectionName) {
		SEDb database;
		database.Initialize(databasePath, true);

		SEDbCollection *collection = database.Collection(collectionName);
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
		model.setProperty("trainingDays", trainingDays);
		model.setProperty("maxCandidateCount", maxCandidateCount);
		model.setProperty("strategyCount", strategyCount);
		model.setProperty("totalDays", totalDays);
		model.setProperty("normalizedCount", normalizedCount);

		JSON::Array *prefixes = new JSON::Array();

		for (int i = 0; i < strategyCount; i++) {
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
		collection.Flush();

		delete model;

		logger.info(StringFormat(
			"Model saved: %s/%s | days=%d normalized=%d strategies=%d",
			databasePath,
			collectionName,
			totalDays,
			normalizedCount,
			strategyCount
		));

		return true;
	}

	bool LoadModel(string databasePath, string collectionName) {
		SEDb database;
		database.Initialize(databasePath, true);

		SEDbCollection *collection = database.Collection(collectionName);

		if (collection.Count() == 0) {
			logger.error(StringFormat(
				"No model found in %s/%s",
				databasePath,
				collectionName
			));

			return false;
		}

		JSON::Object *model = collection.FindOne("type", "allocator_model");

		if (model == NULL) {
			logger.error("No allocator model document found");
			return false;
		}

		int version = (int)model.getNumber("version");

		if (version != 1) {
			logger.error(StringFormat("Unsupported model version: %d", version));
			return false;
		}

		rollingWindowDays = (int)model.getNumber("rollingWindowDays");
		normalizationWindow = (int)model.getNumber("normalizationWindow");
		kNeighbors = (int)model.getNumber("kNeighbors");
		maxActiveStrategies = (int)model.getNumber("maxActiveStrategies");
		scoreThreshold = model.getNumber("scoreThreshold");
		forwardWindow = (int)model.getNumber("forwardWindow");
		trainingDays = (int)model.getNumber("trainingDays");
		maxCandidateCount = (int)model.getNumber("maxCandidateCount");
		strategyCount = (int)model.getNumber("strategyCount");
		totalDays = (int)model.getNumber("totalDays");
		normalizedCount = (int)model.getNumber("normalizedCount");

		JSON::Array *prefixesArray = model.getArray("strategyPrefixes");
		ArrayResize(strategyPrefixes, strategyCount);

		for (int i = 0; i < strategyCount; i++) {
			strategyPrefixes[i] = prefixesArray.getString(i);
		}

		JSON::Array *featuresArray = model.getArray("featureHistory");
		int featureSize = featuresArray.getLength();
		ArrayResize(featureHistory, featureSize);

		for (int i = 0; i < featureSize; i++) {
			featureHistory[i] = featuresArray.getNumber(i);
		}

		JSON::Array *performanceArray = model.getArray("strategyPerformanceHistory");
		int performanceSize = performanceArray.getLength();
		ArrayResize(strategyPerformanceHistory, performanceSize);

		for (int i = 0; i < performanceSize; i++) {
			strategyPerformanceHistory[i] = performanceArray.getNumber(i);
		}

		JSON::Array *normalizedArray = model.getArray("normalizedFeatures");
		int normalizedSize = normalizedArray.getLength();
		ArrayResize(normalizedFeatures, normalizedSize);

		for (int i = 0; i < normalizedSize; i++) {
			normalizedFeatures[i] = normalizedArray.getNumber(i);
		}

		logger.info(StringFormat(
			"Model loaded: %s/%s | days=%d normalized=%d strategies=%d",
			databasePath,
			collectionName,
			totalDays,
			normalizedCount,
			strategyCount
		));

		return true;
	}
};

#endif
