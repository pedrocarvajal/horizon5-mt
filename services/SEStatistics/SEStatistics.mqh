#ifndef __SE_STATISTICS_MQH__
#define __SE_STATISTICS_MQH__

#include "../../structs/SSOrderHistory.mqh"
#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SQualityThresholds.mqh"
#include "../../structs/SSQualityResult.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../../entities/EOrder.mqh"

#include "helpers/HCalculateRSquared.mqh"
#include "helpers/HCalculateSharpeRatio.mqh"
#include "helpers/HCalculateMetricQuality.mqh"
#include "helpers/HCalculateCAGR.mqh"

extern SEDateTime dtime;
extern EOrder orders[];

#define STOP_OUT_THRESHOLD 0.20

class SEStatistics {
private:
	SELogger logger;

	string id;
	string strategyName;
	string strategyPrefix;
	string symbol;
	datetime startTime;

	SQualityThresholds qualityThresholds;

	double nav[];
	double performance[];
	double returns[];

	double navPeak;
	double navYesterday;
	double dailyPerformance;

	double drawdownMaxInDollars;
	double drawdownMaxInPercentage;

	int winningOrders;
	double winningOrdersPerformance;

	int losingOrders;
	double losingOrdersPerformance;
	double maxLoss;

	double riskRewardRatio;
	double winRate;
	double recoveryFactor;

	int monthsInBacktest;
	SSOrderHistory ordersHistory[];
	EOrder lastClosedOrders[];
	SSStatisticsSnapshot snapshots[];

	double maxExposureInLots;
	double maxExposureInPercentage;

	bool stopOutDetected;
	double initialBalance;
	double finalEquity;

	bool detectStopOut() {
		finalEquity = AccountInfoDouble(ACCOUNT_EQUITY);
		double equityPercentage = finalEquity / initialBalance;

		if (equityPercentage < STOP_OUT_THRESHOLD) {
			stopOutDetected = true;
			logger.debug(StringFormat("Stop out detected: Equity %.2f (%.2f%% of initial balance)", finalEquity, equityPercentage * 100));

			return true;
		}

		if (equityPercentage < 0.50) {
			stopOutDetected = true;
			logger.debug(StringFormat("Severe equity loss detected: %.2f%% remaining", equityPercentage * 100));

			return true;
		}

		return false;
	}

	void processPendingOrders() {
		if (ArraySize(lastClosedOrders) == 0)
			return;

		double prevNav = (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : nav[0];
		double prevPerformance = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;

		double nextNav = prevNav;
		double nextPerformance = prevPerformance;

		for (int i = 0; i < ArraySize(lastClosedOrders); i++) {
			EOrder order = lastClosedOrders[i];
			nextPerformance += order.GetProfitInDollars();
			nextNav += order.GetProfitInDollars();

			if (order.GetProfitInDollars() > 0) {
				winningOrders++;
				winningOrdersPerformance += order.GetProfitInDollars();
			} else {
				losingOrders++;
				losingOrdersPerformance += order.GetProfitInDollars();
				double currentLoss = MathAbs(order.GetProfitInDollars());

				if (currentLoss > maxLoss)
					maxLoss = currentLoss;
			}

			if (nextNav > navPeak)
				navPeak = nextNav;
		}

		double drawdownInDollars = navPeak - nextNav;
		double avgWin = (winningOrders > 0) ? winningOrdersPerformance / winningOrders : 0;

		if (drawdownInDollars > drawdownMaxInDollars) {
			drawdownMaxInDollars = drawdownInDollars;
			if (navPeak > 0)
				drawdownMaxInPercentage = drawdownMaxInDollars / navPeak;
			else
				drawdownMaxInPercentage = 0.0;
		}

		winRate = (winningOrders + losingOrders > 0) ? (double)winningOrders / (winningOrders + losingOrders) : 0;
		riskRewardRatio = (maxLoss > 0) ? avgWin / maxLoss : 0;

		if (ArraySize(performance) > 0) {
			performance[ArraySize(performance) - 1] = nextPerformance;
		} else {
			ArrayResize(performance, 1);
			performance[0] = nextPerformance;
		}

		if (ArraySize(nav) > 0) {
			nav[ArraySize(nav) - 1] = nextNav;
		} else {
			ArrayResize(nav, 1);
			nav[0] = nextNav;
		}

		ArrayResize(lastClosedOrders, 0);
	}

	void snapshot() {
		SSQualityResult quality = GetQuality();
		SSStatisticsSnapshot snapshotData;
		snapshotData.timestamp = StructToTime(dtime.Now());
		snapshotData.id = id;

		for (int i = 0; i < ArraySize(ordersHistory); i++) {
			ArrayResize(snapshotData.orders, ArraySize(snapshotData.orders) + 1);
			snapshotData.orders[ArraySize(snapshotData.orders) - 1] = ordersHistory[i];
		}

		for (int i = 0; i < ArraySize(nav); i++) {
			ArrayResize(snapshotData.nav, ArraySize(snapshotData.nav) + 1);
			snapshotData.nav[ArraySize(snapshotData.nav) - 1] = nav[i];
		}

		for (int i = 0; i < ArraySize(performance); i++) {
			ArrayResize(snapshotData.performance, ArraySize(snapshotData.performance) + 1);
			snapshotData.performance[ArraySize(snapshotData.performance) - 1] = performance[i];
		}

		snapshotData.navPeak = navPeak;
		snapshotData.drawdownMaxInDollars = drawdownMaxInDollars;
		snapshotData.drawdownMaxInPercentage = drawdownMaxInPercentage;
		snapshotData.winningOrders = winningOrders;
		snapshotData.winningOrdersPerformance = winningOrdersPerformance;
		snapshotData.losingOrders = losingOrders;
		snapshotData.losingOrdersPerformance = losingOrdersPerformance;
		snapshotData.maxLoss = maxLoss;

		snapshotData.rSquared = GetR2(performance);
		snapshotData.sharpeRatio = GetSharpeRatio(performance);
		snapshotData.riskRewardRatio = riskRewardRatio;
		snapshotData.winRate = winRate;
		snapshotData.recoveryFactor = GetRecoveryFactor();
		snapshotData.cagr = GetCAGR();

		snapshotData.quality = quality.quality;
		snapshotData.qualityReason = quality.reason;

		snapshotData.maxExposureInLots = maxExposureInLots;
		snapshotData.maxExposureInPercentage = maxExposureInPercentage;

		logger.separator(StringFormat("Snapshot: %s", TimeToString(snapshotData.timestamp)));
		logger.debug(StringFormat("Strategy name: %s", strategyName));
		logger.debug(StringFormat("Strategy prefix: %s", strategyPrefix));
		logger.debug(StringFormat("Start time: %s", TimeToString(startTime)));
		logger.debug(StringFormat("Orders: %d", ArraySize(snapshotData.orders)));
		logger.debug(StringFormat("Nav: %.2f", (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : 0.0));
		logger.debug(StringFormat("Performance: %.2f", (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0.0));
		logger.debug(StringFormat("Winning orders: %d", winningOrders));
		logger.debug(StringFormat("Losing orders: %d", losingOrders));
		logger.debug(StringFormat("Winning orders performance: %.2f", winningOrdersPerformance));
		logger.debug(StringFormat("Losing orders performance: %.2f", losingOrdersPerformance));
		logger.debug(StringFormat("Max loss: %.2f", maxLoss));
		logger.debug(StringFormat("Drawdown max in dollars: %.2f", drawdownMaxInDollars));
		logger.debug(StringFormat("Drawdown max in percentage: %.2f%%", drawdownMaxInPercentage * 100));
		logger.debug(StringFormat("Risk/Reward ratio: %.2f", riskRewardRatio));
		logger.debug(StringFormat("Sharpe ratio: %.4f", snapshotData.sharpeRatio));
		logger.debug(StringFormat("Win rate: %.2f%%", winRate * 100));
		logger.debug(StringFormat("Recovery factor: %.2f", snapshotData.recoveryFactor));
		logger.debug(StringFormat("CAGR: %.2f%%", snapshotData.cagr * 100));
		logger.debug(StringFormat("Quality: %.4f", snapshotData.quality));
		logger.debug(StringFormat("Quality reason: %s", snapshotData.qualityReason));
		logger.debug(StringFormat("Max exposure in lots: %.4f", snapshotData.maxExposureInLots));
		logger.debug(StringFormat("Max exposure in percentage: %.4f", snapshotData.maxExposureInPercentage));

		ArrayResize(snapshots, ArraySize(snapshots) + 1);
		snapshots[ArraySize(snapshots) - 1] = snapshotData;
	}

	void updateExposure() {
		double currentExposureLots = 0.0;

		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetSource() != strategyPrefix)
				continue;

			if (orders[i].GetStatus() == ORDER_STATUS_OPEN || orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				if (orders[i].GetSide() == ORDER_TYPE_BUY)
					currentExposureLots += orders[i].GetVolume();

				else if (orders[i].GetSide() == ORDER_TYPE_SELL)
					currentExposureLots -= orders[i].GetVolume();
			}
		}

		if (MathAbs(currentExposureLots) > MathAbs(maxExposureInLots))
			maxExposureInLots = currentExposureLots;

		double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
		double symbolPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
		double currentExposurePercentage = 0.0;

		if (accountEquity > 0)
			currentExposurePercentage = (currentExposureLots * symbolPrice) / accountEquity;

		if (MathAbs(currentExposurePercentage) > MathAbs(maxExposureInPercentage))
			maxExposureInPercentage = currentExposurePercentage;
	}

public:
	SEStatistics(string newSymbol, string name, string prefix, double allocatedBalance) {
		logger.SetPrefix("Statistics[" + name + "]");

		symbol = newSymbol;
		strategyName = name;
		strategyPrefix = prefix;
		initialBalance = allocatedBalance;

		id = TimeToString(StructToTime(dtime.Now()), TIME_DATE | TIME_SECONDS);
		startTime = StructToTime(dtime.Now());
		stopOutDetected = false;
		finalEquity = allocatedBalance;

		ArrayResize(nav, 1);
		nav[0] = allocatedBalance;
		navPeak = nav[0];
		navYesterday = allocatedBalance;
		dailyPerformance = 0.0;

		ArrayResize(performance, 1);
		performance[0] = 0.0;

		ArrayResize(returns, 0);

		drawdownMaxInDollars = 0.0;
		drawdownMaxInPercentage = 0.0;
		maxLoss = 0.0;

		maxExposureInLots = 0.0;
		maxExposureInPercentage = 0.0;
	}

	void OnStartHour() {
		ArrayResize(performance, ArraySize(performance) + 1);
		ArrayResize(nav, ArraySize(nav) + 1);

		double prevNav = (ArraySize(nav) > 1) ? nav[ArraySize(nav) - 2] : nav[0];
		double prevPerformance = (ArraySize(performance) > 1) ? performance[ArraySize(performance) - 2] : 0;

		performance[ArraySize(performance) - 1] = prevPerformance;
		nav[ArraySize(nav) - 1] = prevNav;

		processPendingOrders();
	}

	void OnStartDay() {
		double currentNav = (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : nav[0];
		dailyPerformance = currentNav - navYesterday;
		navYesterday = currentNav;

		ArrayResize(returns, ArraySize(returns) + 1);
		returns[ArraySize(returns) - 1] = dailyPerformance;
	}

	void OnStartWeek() {
	}

	void OnStartMonth(bool saveSnapshot = false) {
		monthsInBacktest++;
		processPendingOrders();

		if (saveSnapshot)
			snapshot();
	}

	void OnOpenOrder(EOrder &order) {
		if (order.GetStatus() == ORDER_STATUS_CANCELLED)
			return;

		updateExposure();
	}

	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		ArrayResize(lastClosedOrders, ArraySize(lastClosedOrders) + 1);
		lastClosedOrders[ArraySize(lastClosedOrders) - 1] = order;

		ArrayResize(ordersHistory, ArraySize(ordersHistory) + 1);
		ordersHistory[ArraySize(ordersHistory) - 1] = order.GetSnapshot();

		updateExposure();
	}

	void OnForceEnd() {
		detectStopOut();
		processPendingOrders();
		snapshot();
	}

	double GetNav() {
		if (ArraySize(nav) == 0)
			return 0.0;

		return nav[ArraySize(nav) - 1];
	}

	double GetInitialBalance() {
		return initialBalance;
	}

	SSQualityResult GetQuality() {
		SSQualityResult result;

		double totalOrders = ArraySize(ordersHistory);
		double totalTrades = winningOrders + losingOrders;
		double snapshotPerformance = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;
		double performanceInPercentage = snapshotPerformance / nav[0];
		double currentRecoveryFactor = GetRecoveryFactor();
		double currentRSquared = GetR2(performance);

		double qPerformance = calculateMetricQuality(
			performanceInPercentage,
			qualityThresholds.expectedTotalReturnPctByMonth * monthsInBacktest,
			qualityThresholds.minTotalReturnPct,
			true
			);

		double qDrawdown = calculateMetricQuality(
			drawdownMaxInPercentage,
			qualityThresholds.expectedMaxDrawdownPct,
			qualityThresholds.maxMaxDrawdownPct,
			false
			);

		double qRiskReward = calculateMetricQuality(
			riskRewardRatio,
			qualityThresholds.expectedRiskRewardRatio,
			qualityThresholds.minRiskRewardRatio,
			true
			);

		double qWinRate = calculateMetricQuality(
			winRate,
			qualityThresholds.expectedWinRate,
			qualityThresholds.minWinRate,
			true
			);

		double qRSquared = calculateMetricQuality(
			currentRSquared,
			qualityThresholds.expectedRSquared,
			qualityThresholds.minRSquared,
			true
			);

		double qTrades = calculateMetricQuality(
			totalTrades,
			qualityThresholds.expectedTrades,
			qualityThresholds.minTrades,
			true
			);

		double qRecoveryFactor = calculateMetricQuality(
			currentRecoveryFactor,
			qualityThresholds.expectedRecoveryFactor,
			qualityThresholds.minRecoveryFactor,
			true
			);

		logger.debug("Quality performance results:");
		logger.debug(StringFormat("Performance: %.4f", qPerformance));
		logger.debug(StringFormat("Drawdown: %.4f", qDrawdown));
		logger.debug(StringFormat("Risk-reward: %.4f", qRiskReward));
		logger.debug(StringFormat("Win rate: %.4f", qWinRate));
		logger.debug(StringFormat("R-squared: %.4f", qRSquared));
		logger.debug(StringFormat("Trades: %.4f", qTrades));

		if (stopOutDetected) {
			result.quality = 0;
			result.reason = "Stop out detected.";
			logger.debug(result.reason);
			return result;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_PERFORMANCE) {
			if (qPerformance == 0) {
				result.quality = 0;
				result.reason = "Performance below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qPerformance;
			result.reason = NULL;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_DRAWDOWN) {
			if (qDrawdown == 0) {
				result.quality = 0;
				result.reason = "Drawdown below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qDrawdown;
			result.reason = NULL;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_RISK_REWARD) {
			if (qRiskReward == 0) {
				result.quality = 0;
				result.reason = "Risk-reward ratio below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qRiskReward;
			result.reason = NULL;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_WIN_RATE) {
			if (qWinRate == 0) {
				result.quality = 0;
				result.reason = "Win rate below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qWinRate;
			result.reason = NULL;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_R_SQUARED) {
			if (qRSquared == 0) {
				result.quality = 0;
				result.reason = "R-squared below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qRSquared;
			result.reason = NULL;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_TRADES) {
			if (qTrades == 0) {
				result.quality = 0;
				result.reason = "Number of trades below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qTrades;
			result.reason = NULL;
		}

		if (qualityThresholds.optimizationFormula == OPTIMIZATION_BY_RECOVERY_FACTOR) {
			if (qRecoveryFactor == 0) {
				result.quality = 0;
				result.reason = "Recovery factor below minimum threshold";
				logger.debug(result.reason);
				return result;
			}

			result.quality = qRecoveryFactor;
			result.reason = NULL;
		}

		return result;
	}

	double GetR2(double &points[]) {
		return calculateRSquared(points);
	}

	double GetRecoveryFactor() {
		if (drawdownMaxInDollars <= 0.0000001)
			return 0;

		double totalProfit = (ArraySize(performance) > 0) ? performance[ArraySize(performance) - 1] : 0;
		return totalProfit / drawdownMaxInDollars;
	}

	double GetSharpeRatio(double &perf[]) {
		return calculateSharpeRatio(perf);
	}

	double GetCAGR() {
		double currentNav = (ArraySize(nav) > 0) ? nav[ArraySize(nav) - 1] : initialBalance;

		return calculateCAGR(initialBalance, currentNav, monthsInBacktest);
	}

	void SetQualityThresholds(SQualityThresholds &thresholds) {
		qualityThresholds = thresholds;
	}
};

#endif
