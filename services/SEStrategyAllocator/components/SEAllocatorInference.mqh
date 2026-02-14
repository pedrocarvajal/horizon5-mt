#ifndef __SE_ALLOCATOR_INFERENCE_MQH__
#define __SE_ALLOCATOR_INFERENCE_MQH__

#include "SEAllocatorConstants.mqh"
#include "../../SEDb/SEDb.mqh"
#include "../../SELogger/SELogger.mqh"

class SEAllocatorInference {
private:
	SELogger logger;

	int kNeighbors;
	int maxActiveStrategies;
	int forwardWindow;
	int normalizationWindow;
	int maxCandidateCount;
	int performanceDaysCount;
	double epsilon;
	double scoreThreshold;

	int strategyCount;
	string strategyPrefixes[];
	double strategyPerformanceHistory[];

	int featureIndex(int day, int feature) {
		return day * ALLOCATOR_FEATURE_COUNT + feature;
	}

	int performanceIndex(int day, int strategy) {
		return day * strategyCount + strategy;
	}

	double euclideanDistance(double &normalizedFeatures[], int indexA, int indexB) {
		double sum = 0.0;

		for (int f = 0; f < ALLOCATOR_FEATURE_COUNT; f++) {
			double diff = normalizedFeatures[featureIndex(indexA, f)]
				      - normalizedFeatures[featureIndex(indexB, f)];
			sum += diff * diff;
		}

		return MathSqrt(sum);
	}

	int computeNeighborDistances(
		double &normalizedFeatures[],
		int normalizedCount,
		double &distances[],
		int &distanceIndices[],
		double &weightSum
	) {
		int todayNormIndex = normalizedCount - 1;
		int candidateCount = maxCandidateCount;

		if (candidateCount < 1) {
			logger.Debug("KNN skipped: no training candidates available");
			return 0;
		}

		ArrayResize(distances, candidateCount);
		ArrayResize(distanceIndices, candidateCount);

		for (int p = 0; p < candidateCount; p++) {
			distances[p] = euclideanDistance(normalizedFeatures, todayNormIndex, p);
			distanceIndices[p] = p;
		}

		sortDistances(distances, distanceIndices, candidateCount);

		int neighborsCount = MathMin(kNeighbors, candidateCount);
		weightSum = 0.0;

		for (int n = 0; n < neighborsCount; n++) {
			weightSum += 1.0 / (distances[n] + epsilon);
		}

		logger.Debug(StringFormat(
			"KNN: %d neighbors from %d candidates, distances [%.4f..%.4f]",
			neighborsCount,
			candidateCount,
			distances[0],
			distances[neighborsCount - 1]
		));

		string topNeighborsLog = "Top neighbors: ";
		int logCount = MathMin(5, neighborsCount);

		for (int n = 0; n < logCount; n++) {
			int neighborNormIdx = distanceIndices[n];
			int originalDay = neighborNormIdx + normalizationWindow;

			if (n > 0)
				topNeighborsLog += " ";

			topNeighborsLog += StringFormat(
				"[normIdx=%d day=%d dist=%.4f]",
				neighborNormIdx,
				originalDay,
				distances[n]
			);
		}

		logger.Debug(topNeighborsLog);

		return neighborsCount;
	}

	void computeStrategyScores(
		double &strategyScores[],
		double &distances[],
		int &distanceIndices[],
		int neighborsCount,
		double weightSum
	) {
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
				int forwardEnd = MathMin(originalDayIndex + forwardWindow, performanceDaysCount);

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

		logger.Debug(scoresLog);
	}

	void selectActiveStrategies(double &strategyScores[], string &activeStrategies[]) {
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

		logger.Info(activeLog);
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
	SEAllocatorInference() {
		logger.SetPrefix("SEStrategyAllocatorInference");
		epsilon = ALLOCATOR_EPSILON;
		performanceDaysCount = 0;
	}

	void ComputeActivations(double &normalizedFeatures[], int normalizedCount, string &activeStrategies[]) {
		double distances[];
		int distanceIndices[];
		double weightSum = 0.0;

		int neighborsCount = computeNeighborDistances(normalizedFeatures, normalizedCount, distances, distanceIndices, weightSum);

		if (neighborsCount < 1)
			return;

		double strategyScores[];
		computeStrategyScores(strategyScores, distances, distanceIndices, neighborsCount, weightSum);

		selectActiveStrategies(strategyScores, activeStrategies);
	}

	bool LoadModel(
		string databasePath,
		string collectionName,
		int &outRollingWindowDays,
		int &outNormalizationWindow,
		int &outKNeighbors,
		int &outMaxActiveStrategies,
		double &outScoreThreshold,
		int &outForwardWindow,
		int &outMaxCandidateCount,
		int &outStrategyCount,
		string &outStrategyPrefixes[],
		int &outTotalDays,
		int &outNormalizedCount,
		double &outFeatureHistory[],
		double &outNormalizedFeatures[]
	) {
		SEDb database;
		database.Initialize(databasePath, true);

		SEDbCollection *collection = database.Collection(collectionName);

		if (collection == NULL) {
			logger.Error(StringFormat("Failed to open collection %s/%s", databasePath, collectionName));
			return false;
		}

		if (collection.Count() == 0) {
			logger.Error(StringFormat(
				"No model found in %s/%s",
				databasePath,
				collectionName
			));

			return false;
		}

		JSON::Object *model = collection.FindOne("type", "allocator_model");

		if (model == NULL) {
			logger.Error("No allocator model document found");
			return false;
		}

		int version = (int)model.getNumber("version");

		if (version != 1) {
			logger.Error(StringFormat("Unsupported model version: %d", version));
			return false;
		}

		int modelNormalizedCount = (int)model.getNumber("normalizedCount");
		int modelMaxCandidateCount = (int)model.getNumber("maxCandidateCount");

		if (modelNormalizedCount < 1 || modelMaxCandidateCount < 1) {
			logger.Error(StringFormat(
				"Invalid model: normalizedCount=%d, maxCandidateCount=%d. Model was trained with insufficient data.",
				modelNormalizedCount,
				modelMaxCandidateCount
			));
			return false;
		}

		outRollingWindowDays = (int)model.getNumber("rollingWindowDays");
		outNormalizationWindow = (int)model.getNumber("normalizationWindow");
		outKNeighbors = (int)model.getNumber("kNeighbors");
		outMaxActiveStrategies = (int)model.getNumber("maxActiveStrategies");
		outScoreThreshold = model.getNumber("scoreThreshold");
		outForwardWindow = (int)model.getNumber("forwardWindow");
		outMaxCandidateCount = (int)model.getNumber("maxCandidateCount");
		outStrategyCount = (int)model.getNumber("strategyCount");
		outTotalDays = (int)model.getNumber("totalDays");
		outNormalizedCount = (int)model.getNumber("normalizedCount");

		kNeighbors = outKNeighbors;
		maxActiveStrategies = outMaxActiveStrategies;
		scoreThreshold = outScoreThreshold;
		forwardWindow = outForwardWindow;
		normalizationWindow = outNormalizationWindow;
		maxCandidateCount = outMaxCandidateCount;
		strategyCount = outStrategyCount;

		JSON::Array *prefixesArray = model.getArray("strategyPrefixes");

		if (prefixesArray == NULL) {
			logger.Error("Missing strategyPrefixes in model");
			return false;
		}

		ArrayResize(outStrategyPrefixes, outStrategyCount);
		ArrayResize(strategyPrefixes, outStrategyCount);

		for (int i = 0; i < outStrategyCount; i++) {
			outStrategyPrefixes[i] = prefixesArray.getString(i);
			strategyPrefixes[i] = outStrategyPrefixes[i];
		}

		JSON::Array *featuresArray = model.getArray("featureHistory");

		if (featuresArray == NULL) {
			logger.Error("Missing featureHistory in model");
			return false;
		}

		int featureSize = featuresArray.getLength();
		ArrayResize(outFeatureHistory, featureSize);

		for (int i = 0; i < featureSize; i++) {
			outFeatureHistory[i] = featuresArray.getNumber(i);
		}

		JSON::Array *performanceArray = model.getArray("strategyPerformanceHistory");

		if (performanceArray == NULL) {
			logger.Error("Missing strategyPerformanceHistory in model");
			return false;
		}

		int performanceSize = performanceArray.getLength();
		ArrayResize(strategyPerformanceHistory, performanceSize);
		performanceDaysCount = (strategyCount > 0) ? performanceSize / strategyCount : 0;

		for (int i = 0; i < performanceSize; i++) {
			strategyPerformanceHistory[i] = performanceArray.getNumber(i);
		}

		JSON::Array *normalizedArray = model.getArray("normalizedFeatures");

		if (normalizedArray == NULL) {
			logger.Error("Missing normalizedFeatures in model");
			return false;
		}

		int normalizedSize = normalizedArray.getLength();
		ArrayResize(outNormalizedFeatures, normalizedSize);

		for (int i = 0; i < normalizedSize; i++) {
			outNormalizedFeatures[i] = normalizedArray.getNumber(i);
		}

		logger.Info(StringFormat(
			"Model loaded: %s/%s | days=%d normalized=%d strategies=%d",
			databasePath,
			collectionName,
			outTotalDays,
			outNormalizedCount,
			outStrategyCount
		));

		logger.Info(StringFormat(
			"Model arrays: features=%d performance=%d (days=%d) normalized=%d | params: norm=%d candidates=%d k=%d forward=%d",
			ArraySize(outFeatureHistory),
			ArraySize(strategyPerformanceHistory),
			performanceDaysCount,
			ArraySize(outNormalizedFeatures),
			outNormalizationWindow,
			outMaxCandidateCount,
			outKNeighbors,
			outForwardWindow
		));

		return true;
	}
};

#endif
