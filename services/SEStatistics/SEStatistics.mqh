#ifndef __SE_STATISTICS_MQH__
#define __SE_STATISTICS_MQH__

#include "../../structs/SSOrderHistory.mqh"
#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SQualityThresholds.mqh"
#include "../../structs/SSQualityResult.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../../entities/EOrder.mqh"

#include "helpers/HCalculateRSquared.mqh"
#include "helpers/HCalculateSharpeRatio.mqh"
#include "helpers/HCalculateMetricQuality.mqh"
#include "helpers/HCalculateCAGR.mqh"
#include "helpers/HCalculateStability.mqh"

extern SEDateTime dtime;

#define STOP_OUT_THRESHOLD      0.20
#define SEVERE_LOSS_THRESHOLD   0.50

class SEStatistics {
private:
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

	SSOrderHistory ordersHistory[];
	EOrder lastClosedOrders[];
	SSStatisticsSnapshot snapshots[];

	double maxExposureInLots;
	double maxExposureInPercentage;

	bool stopOutDetected;
	double initialBalance;
	double finalEquity;

	int getMonthsElapsed() {
		SDateTime start = dtime.FromTimestamp(startTime);
		SDateTime now = dtime.Now();
		int months = (now.year - start.year) * 12 + (now.month - start.month);
		return MathMax(months, 0);
	}

	bool detectStopOut() {
		finalEquity = AccountInfoDouble(ACCOUNT_EQUITY);
		double equityPercentage = finalEquity / initialBalance;

		if (equityPercentage < STOP_OUT_THRESHOLD) {
			stopOutDetected = true;
			return true;
		}

		if (equityPercentage < SEVERE_LOSS_THRESHOLD) {
			stopOutDetected = true;
			return true;
		}

		return false;
	}

	void recordOrderResult(EOrder &order, double &nextPerformance) {
		double profit = order.GetProfitInDollars();
		nextPerformance += profit;

		if (profit > 0) {
			winningOrders++;
			winningOrdersPerformance += profit;
		} else {
			losingOrders++;
			losingOrdersPerformance += profit;
			double currentLoss = MathAbs(profit);

			if (currentLoss > maxLoss)
				maxLoss = currentLoss;
		}
	}

	void updateRatios() {
		double avgWin = (winningOrders > 0)
			? winningOrdersPerformance / winningOrders
			: 0;

		int totalOrders = winningOrders + losingOrders;
		winRate = (totalOrders > 0)
			? (double)winningOrders / totalOrders
			: 0;

		riskRewardRatio = (maxLoss > 0) ? avgWin / maxLoss : 0;
	}

	void updatePerformance(double nextPerformance) {
		if (ArraySize(performance) > 0) {
			performance[ArraySize(performance) - 1] = nextPerformance;
		} else {
			ArrayResize(performance, 1);
			performance[0] = nextPerformance;
		}
	}

	void processPendingOrders() {
		if (ArraySize(lastClosedOrders) == 0)
			return;

		int lastIndex = ArraySize(performance) - 1;
		double prevPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;
		double nextPerformance = prevPerformance;

		for (int i = 0; i < ArraySize(lastClosedOrders); i++) {
			recordOrderResult(lastClosedOrders[i], nextPerformance);
		}

		updateRatios();
		updatePerformance(nextPerformance);

		ArrayResize(lastClosedOrders, 0);
	}

	SSStatisticsSnapshot buildSnapshotData(SSQualityResult &quality) {
		SSStatisticsSnapshot snapshotData;
		snapshotData.timestamp = dtime.Now().timestamp;
		snapshotData.id = id;

		ArrayResize(snapshotData.orders, ArraySize(ordersHistory));
		for (int i = 0; i < ArraySize(ordersHistory); i++) {
			snapshotData.orders[i] = ordersHistory[i];
		}

		ArrayResize(snapshotData.nav, ArraySize(nav));
		ArrayCopy(snapshotData.nav, nav);

		ArrayResize(snapshotData.performance, ArraySize(performance));
		ArrayCopy(snapshotData.performance, performance);

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
		snapshotData.stability = GetStability();
		snapshotData.stabilitySQ3 = GetStabilitySQ3();

		snapshotData.quality = quality.quality;
		snapshotData.qualityReason = quality.reason;

		snapshotData.maxExposureInLots = maxExposureInLots;
		snapshotData.maxExposureInPercentage = maxExposureInPercentage;

		if (ArraySize(nav) > 1 && nav[ArraySize(nav) - 2] != 0.0)
			snapshotData.dailyPerformance = dailyPerformance / nav[ArraySize(nav) - 2];
		else
			snapshotData.dailyPerformance = 0.0;

		return snapshotData;
	}

	void snapshot() {
		SSQualityResult quality = GetQuality();
		SSStatisticsSnapshot snapshotData = buildSnapshotData(quality);

		ArrayResize(snapshots, ArraySize(snapshots) + 1);
		snapshots[ArraySize(snapshots) - 1] = snapshotData;
	}

	double calculateFloatingPnL(EOrder &strategyOrders[]) {
		double floatingPnL = 0.0;

		for (int i = 0; i < ArraySize(strategyOrders); i++) {
			if (strategyOrders[i].GetStatus() == ORDER_STATUS_OPEN)
				floatingPnL += strategyOrders[i].GetFloatingPnL();
		}

		return floatingPnL;
	}

	double calculatePendingClosedProfit() {
		double pendingProfit = 0.0;

		for (int i = 0; i < ArraySize(lastClosedOrders); i++) {
			pendingProfit += lastClosedOrders[i].GetProfitInDollars();
		}

		return pendingProfit;
	}

	void updateDrawdownWithFloatingPnL(EOrder &strategyOrders[]) {
		int lastIndex = ArraySize(performance) - 1;
		double currentPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;
		double pendingClosedProfit = calculatePendingClosedProfit();
		double floatingPnL = calculateFloatingPnL(strategyOrders);
		double realNav = initialBalance + currentPerformance + pendingClosedProfit + floatingPnL;
		double drawdownInDollars = navPeak - realNav;

		if (drawdownInDollars > drawdownMaxInDollars) {
			drawdownMaxInDollars = drawdownInDollars;
			drawdownMaxInPercentage = (navPeak > 0)
				? drawdownMaxInDollars / navPeak
				: 0.0;
		}
	}

	void updateExposure(EOrder &strategyOrders[]) {
		double currentExposureLots = 0.0;

		for (int i = 0; i < ArraySize(strategyOrders); i++) {
			if (strategyOrders[i].GetStatus() == ORDER_STATUS_OPEN ||
			    strategyOrders[i].GetStatus() == ORDER_STATUS_PENDING) {
				if (strategyOrders[i].GetSide() == ORDER_TYPE_BUY)
					currentExposureLots += strategyOrders[i].GetVolume();
				else if (strategyOrders[i].GetSide() == ORDER_TYPE_SELL)
					currentExposureLots -= strategyOrders[i].GetVolume();
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

	bool evaluateOptimizationFormula(
		int formula, double qualityValue,
		SSQualityResult &result, string failReason
	) {
		if (qualityThresholds.optimizationFormula != formula)
			return false;

		if (qualityValue == 0) {
			result.quality = 0;
			result.reason = failReason;
			return true;
		}

		result.quality = qualityValue;
		result.reason = NULL;
		return true;
	}

public:
	SEStatistics(string newSymbol, string name, string prefix, double allocatedBalance) {
		symbol = newSymbol;
		strategyName = name;
		strategyPrefix = prefix;
		initialBalance = allocatedBalance;

		id = TimeToString(dtime.Now().timestamp, TIME_DATE | TIME_SECONDS);
		startTime = dtime.Now().timestamp;
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

	double GetDailyPerformancePercent() {
		if (ArraySize(nav) > 1 && nav[ArraySize(nav) - 2] != 0.0)
			return dailyPerformance / nav[ArraySize(nav) - 2];

		return 0.0;
	}

	double GetCAGR() {
		int lastIndex = ArraySize(nav) - 1;
		double currentNav = (lastIndex >= 0) ? nav[lastIndex] : initialBalance;
		return CalculateCAGR(initialBalance, currentNav, getMonthsElapsed());
	}

	double GetStability() {
		int lastIndex = ArraySize(performance) - 1;
		double totalProfit = (lastIndex >= 0) ? performance[lastIndex] : 0;
		return CalculateStability(nav, totalProfit);
	}

	double GetStabilitySQ3() {
		int lastIndex = ArraySize(performance) - 1;
		double totalProfit = (lastIndex >= 0) ? performance[lastIndex] : 0;
		int totalTrades = winningOrders + losingOrders;
		return CalculateStabilitySQ3(nav, totalProfit, totalTrades);
	}

	double GetInitialBalance() {
		return initialBalance;
	}

	double GetNav() {
		if (ArraySize(nav) == 0)
			return 0.0;

		return nav[ArraySize(nav) - 1];
	}

	SSQualityResult GetQuality() {
		SSQualityResult result;

		if (stopOutDetected) {
			result.quality = 0;
			result.reason = "Stop out detected.";
			return result;
		}

		double totalTrades = winningOrders + losingOrders;
		int lastIndex = ArraySize(performance) - 1;
		double snapshotPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;
		double performanceInPercentage = snapshotPerformance / nav[0];
		double currentRecoveryFactor = GetRecoveryFactor();
		double currentRSquared = GetR2(performance);

		double qPerformance = CalculateMetricQuality(
			performanceInPercentage,
			qualityThresholds.expectedTotalReturnPctByMonth * getMonthsElapsed(),
			qualityThresholds.minTotalReturnPct,
			true);

		double qDrawdown = CalculateMetricQuality(
			drawdownMaxInPercentage,
			qualityThresholds.expectedMaxDrawdownPct,
			qualityThresholds.maxMaxDrawdownPct,
			false);

		double qRiskReward = CalculateMetricQuality(
			riskRewardRatio,
			qualityThresholds.expectedRiskRewardRatio,
			qualityThresholds.minRiskRewardRatio,
			true);

		double qWinRate = CalculateMetricQuality(
			winRate,
			qualityThresholds.expectedWinRate,
			qualityThresholds.minWinRate,
			true);

		double qRSquared = CalculateMetricQuality(
			currentRSquared,
			qualityThresholds.expectedRSquared,
			qualityThresholds.minRSquared,
			true);

		double qTrades = CalculateMetricQuality(
			totalTrades,
			qualityThresholds.expectedTrades,
			qualityThresholds.minTrades,
			true);

		double qRecoveryFactor = CalculateMetricQuality(
			currentRecoveryFactor,
			qualityThresholds.expectedRecoveryFactor,
			qualityThresholds.minRecoveryFactor,
			true);

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_PERFORMANCE, qPerformance,
			result, "Performance below minimum threshold"))
			return result;

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_DRAWDOWN, qDrawdown,
			result, "Drawdown below minimum threshold"))
			return result;

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_RISK_REWARD, qRiskReward,
			result, "Risk-reward ratio below minimum threshold"))
			return result;

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_WIN_RATE, qWinRate,
			result, "Win rate below minimum threshold"))
			return result;

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_R_SQUARED, qRSquared,
			result, "R-squared below minimum threshold"))
			return result;

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_TRADES, qTrades,
			result, "Number of trades below minimum threshold"))
			return result;

		if (evaluateOptimizationFormula(
			OPTIMIZATION_BY_RECOVERY_FACTOR, qRecoveryFactor,
			result, "Recovery factor below minimum threshold"))
			return result;

		return result;
	}

	double GetR2(double &points[]) {
		return CalculateRSquared(points);
	}

	double GetRecoveryFactor() {
		if (drawdownMaxInDollars <= 0.0000001)
			return 0;

		int lastIndex = ArraySize(performance) - 1;
		double totalProfit = (lastIndex >= 0) ? performance[lastIndex] : 0;
		return totalProfit / drawdownMaxInDollars;
	}

	double GetSharpeRatio(double &perf[]) {
		return CalculateSharpeRatio(perf);
	}

	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason, EOrder &strategyOrders[]) {
		ArrayResize(lastClosedOrders, ArraySize(lastClosedOrders) + 1);
		lastClosedOrders[ArraySize(lastClosedOrders) - 1] = order;

		ArrayResize(ordersHistory, ArraySize(ordersHistory) + 1);
		ordersHistory[ArraySize(ordersHistory) - 1] = order.GetSnapshot();

		updateExposure(strategyOrders);
		updateDrawdownWithFloatingPnL(strategyOrders);
	}

	void OnForceEnd() {
		detectStopOut();
		processPendingOrders();
		snapshot();
	}

	void OnOpenOrder(EOrder &order, EOrder &strategyOrders[]) {
		if (order.GetStatus() == ORDER_STATUS_CANCELLED)
			return;

		updateExposure(strategyOrders);
		updateDrawdownWithFloatingPnL(strategyOrders);
	}

	void OnStartDay(EOrder &strategyOrders[]) {
		processPendingOrders();

		ArrayResize(performance, ArraySize(performance) + 1);
		ArrayResize(nav, ArraySize(nav) + 1);

		int lastIndex = ArraySize(performance) - 2;
		double prevPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;
		performance[ArraySize(performance) - 1] = prevPerformance;

		double floatingPnL = calculateFloatingPnL(strategyOrders);
		double closedNav = initialBalance + prevPerformance;
		double realNav = closedNav + floatingPnL;

		nav[ArraySize(nav) - 1] = realNav;

		if (realNav > navPeak)
			navPeak = realNav;

		updateDrawdownWithFloatingPnL(strategyOrders);

		dailyPerformance = realNav - navYesterday;
		navYesterday = realNav;

		ArrayResize(returns, ArraySize(returns) + 1);
		returns[ArraySize(returns) - 1] = dailyPerformance;
	}

	void OnStartHour() {
	}

	void SetQualityThresholds(SQualityThresholds &thresholds) {
		qualityThresholds = thresholds;
	}

	SSStatisticsSnapshot GetDailySnapshot() {
		processPendingOrders();
		SSQualityResult quality = GetQuality();
		SSStatisticsSnapshot snapshotData = buildSnapshotData(quality);
		ArrayResize(snapshotData.orders, 0);
		return snapshotData;
	}
};

#endif
