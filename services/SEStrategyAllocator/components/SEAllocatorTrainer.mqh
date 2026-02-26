#ifndef __SE_ALLOCATOR_TRAINER_MQH__
#define __SE_ALLOCATOR_TRAINER_MQH__

#include "SEAllocatorConstants.mqh"
#include "../../SEDb/SEDb.mqh"
#include "../../SELogger/SELogger.mqh"
#include "../../SRReportOfAllocatorAnalysis/SRReportOfAllocatorAnalysis.mqh"

class SEAllocatorTrainer {
private:
	SELogger * logger;
	int strategyCount;
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

	double computeScoreForHorizon(
		double &distances[],
		int &distanceIndices[],
		int neighborsCount,
		double weightSum,
		int normalizationWindow,
		int totalDays,
		int horizon,
		int strategy
	) {
		double weightedSum = 0.0;

		for (int n = 0; n < neighborsCount; n++) {
			int neighborNormIndex = distanceIndices[n];
			int originalDayIndex = neighborNormIndex + normalizationWindow;
			double weight = 1.0 / (distances[n] + ALLOCATOR_EPSILON);

			double forwardPerformanceSum = 0.0;
			int forwardCount = 0;
			int forwardEnd = MathMin(originalDayIndex + horizon, totalDays);

			for (int fw = originalDayIndex; fw < forwardEnd; fw++) {
				forwardPerformanceSum += strategyPerformanceHistory[performanceIndex(fw, strategy)];
				forwardCount++;
			}

			double averageForwardPerformance = (forwardCount > 0)
				? forwardPerformanceSum / forwardCount
				: 0.0;

			weightedSum += weight * averageForwardPerformance;
		}

		return (weightSum > 0.0) ? weightedSum / weightSum : 0.0;
	}

	double computeActualForwardPerformance(int originalDayIndex, int totalDays, int horizon, int strategy) {
		double sum = 0.0;
		int count = 0;
		int forwardEnd = MathMin(originalDayIndex + horizon, totalDays);

		for (int fw = originalDayIndex; fw < forwardEnd; fw++) {
			sum += strategyPerformanceHistory[performanceIndex(fw, strategy)];
			count++;
		}

		return (count > 0) ? sum / count : 0.0;
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

	void RunAnalysis(
		string symbol,
		int kNeighbors,
		int normalizationWindow,
		int maxCandidateCount,
		int totalStrategyCount,
		string &strategyPrefixes[],
		int totalDays,
		int normalizedCount,
		double &featureHistory[],
		double &normalizedFeatures[]
	) {
		if (maxCandidateCount < 2) {
			logger.Error("RunAnalysis: not enough candidates for leave-one-out analysis");
			return;
		}

		int horizons[] = { 1, 2, 3, 5, 10 };
		int horizonCount = ArraySize(horizons);
		int maxHorizon = horizons[horizonCount - 1];

		int analysisEnd = normalizedCount - maxHorizon;

		if (analysisEnd < 1) {
			logger.Error(StringFormat(
				"RunAnalysis: not enough data for max horizon (normalizedCount=%d, maxHorizon=%d)",
				normalizedCount,
				maxHorizon
			));
			return;
		}

		string reportName = StringFormat("%s_Allocator_Analysis", symbol);
		SRReportOfAllocatorAnalysis reporter(symbol, reportName);

		logger.Info(StringFormat(
			"Running analysis: %d candidate days, %d strategies, horizons=[1,2,3,5,10]",
			analysisEnd,
			totalStrategyCount
		));

		for (int candidateNormIdx = 0; candidateNormIdx < analysisEnd; candidateNormIdx++) {
			int candidateOriginalDay = candidateNormIdx + normalizationWindow;
			int candidatePoolSize = MathMin(maxCandidateCount, normalizedCount);

			double distances[];
			int distanceIndices[];
			ArrayResize(distances, candidatePoolSize - 1);
			ArrayResize(distanceIndices, candidatePoolSize - 1);

			int poolIdx = 0;

			for (int p = 0; p < candidatePoolSize; p++) {
				if (p == candidateNormIdx) {
					continue;
				}

				distances[poolIdx] = euclideanDistance(normalizedFeatures, candidateNormIdx, p);
				distanceIndices[poolIdx] = p;
				poolIdx++;
			}

			sortDistances(distances, distanceIndices, poolIdx);

			int neighborsCount = MathMin(kNeighbors, poolIdx);
			double weightSum = 0.0;

			for (int n = 0; n < neighborsCount; n++) {
				weightSum += 1.0 / (distances[n] + ALLOCATOR_EPSILON);
			}

			double averageNeighborDistance = 0.0;

			for (int n = 0; n < neighborsCount; n++) {
				averageNeighborDistance += distances[n];
			}

			averageNeighborDistance = (neighborsCount > 0)
				? averageNeighborDistance / neighborsCount
				: 0.0;

			int scoresSize = totalStrategyCount * horizonCount;
			double scores[];
			ArrayResize(scores, scoresSize);

			int forwardSize = totalStrategyCount * horizonCount;
			double forwardPerformances[];
			ArrayResize(forwardPerformances, forwardSize);

			double scoreStds[];
			ArrayResize(scoreStds, scoresSize);

			for (int s = 0; s < totalStrategyCount; s++) {
				for (int h = 0; h < horizonCount; h++) {
					int idx = s * horizonCount + h;

					scores[idx] = computeScoreForHorizon(
						distances,
						distanceIndices,
						neighborsCount,
						weightSum,
						normalizationWindow,
						totalDays,
						horizons[h],
						s
					);

					forwardPerformances[idx] = computeActualForwardPerformance(
						candidateOriginalDay,
						totalDays,
						horizons[h],
						s
					);

					double neighborForwards[];
					ArrayResize(neighborForwards, neighborsCount);

					for (int n = 0; n < neighborsCount; n++) {
						int neighborNormIndex = distanceIndices[n];
						int neighborOriginalDay = neighborNormIndex + normalizationWindow;
						neighborForwards[n] = computeActualForwardPerformance(
							neighborOriginalDay,
							totalDays,
							horizons[h],
							s
						);
					}

					double mean = scores[idx];
					double sumSquaredDiff = 0.0;

					for (int n = 0; n < neighborsCount; n++) {
						double diff = neighborForwards[n] - mean;
						sumSquaredDiff += diff * diff;
					}

					scoreStds[idx] = (neighborsCount > 1)
						? MathSqrt(sumSquaredDiff / (neighborsCount - 1))
						: 0.0;
				}
			}

			reporter.AddDayRecord(
				candidateOriginalDay,
				featureHistory[featureIndex(candidateOriginalDay, 0)],
				featureHistory[featureIndex(candidateOriginalDay, 1)],
				featureHistory[featureIndex(candidateOriginalDay, 2)],
				normalizedFeatures[featureIndex(candidateNormIdx, 0)],
				normalizedFeatures[featureIndex(candidateNormIdx, 1)],
				normalizedFeatures[featureIndex(candidateNormIdx, 2)],
				averageNeighborDistance,
				neighborsCount,
				totalStrategyCount,
				strategyPrefixes,
				scores,
				forwardPerformances,
				scoreStds
			);
		}

		reporter.Export();

		logger.Info(StringFormat(
			"Analysis complete: %d records exported",
			reporter.GetRecordCount()
		));
	}
};

#endif
