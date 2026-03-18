#ifndef __SE_STATISTICS_MQH__
#define __SE_STATISTICS_MQH__

#include "../../structs/SSOrderHistory.mqh"
#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SSQualityResult.mqh"
#include "../../structs/SStatisticsState.mqh"

#include "../SEDateTime/SEDateTime.mqh"

#include "../../entities/EOrder.mqh"

extern SEDateTime dtime;

#define DRAWDOWN_EPSILON 0.0000001

class SEStatistics {
private:
	string id;
	datetime startTime;

	double nav[];
	double performance[];
	double returns[];

	double navPeak;
	double navYesterday;
	double dailyPerformance;

	double drawdownMaxInDollars;
	double drawdownMaxInPercentage;

	SSOrderHistory ordersHistory[];
	EOrder lastClosedOrders[];

	double initialBalance;

	void updatePerformance(double nextPerformance) {
		performance[ArraySize(performance) - 1] = nextPerformance;
	}

	void processPendingOrders() {
		if (ArraySize(lastClosedOrders) == 0) {
			return;
		}

		int lastIndex = ArraySize(performance) - 1;
		double prevPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;
		double nextPerformance = prevPerformance;

		for (int i = 0; i < ArraySize(lastClosedOrders); i++) {
			nextPerformance += lastClosedOrders[i].GetProfitInDollars();
		}

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

		snapshotData.quality = quality.quality;
		snapshotData.qualityReason = quality.reason;

		if (ArraySize(nav) > 1 && nav[ArraySize(nav) - 2] != 0.0) {
			snapshotData.dailyPerformance = dailyPerformance / nav[ArraySize(nav) - 2];
		} else {
			snapshotData.dailyPerformance = 0.0;
		}

		return snapshotData;
	}

	double calculateFloatingPnL(EOrder &strategyOrders[]) {
		double floatingPnL = 0.0;

		for (int i = 0; i < ArraySize(strategyOrders); i++) {
			if (strategyOrders[i].GetStatus() == ORDER_STATUS_OPEN) {
				floatingPnL += strategyOrders[i].GetFloatingPnL();
			}
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

public:
	SEStatistics(double allocatedBalance) {
		initialBalance = allocatedBalance;

		id = TimeToString(dtime.Now().timestamp, TIME_DATE | TIME_SECONDS);
		startTime = dtime.Now().timestamp;

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
	}

	double GetInitialBalance() {
		return initialBalance;
	}

	double GetNav() {
		if (ArraySize(nav) == 0) {
			return 0.0;
		}

		return nav[ArraySize(nav) - 1];
	}

	double GetClosedNav() {
		int lastIndex = ArraySize(performance) - 1;
		double currentPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;
		return initialBalance + currentPerformance + calculatePendingClosedProfit();
	}

	double GetNavPeak() {
		return navPeak;
	}

	double GetDailyPerformance() {
		return dailyPerformance;
	}

	datetime GetStartTime() {
		return startTime;
	}

	double GetNavYesterday() {
		return navYesterday;
	}

	double GetDrawdownMaxInDollars() {
		return drawdownMaxInDollars;
	}

	double GetDrawdownMaxInPercentage() {
		return drawdownMaxInPercentage;
	}

	void GetNavArray(double &target[]) {
		ArrayResize(target, ArraySize(nav));
		ArrayCopy(target, nav);
	}

	void GetPerformanceArray(double &target[]) {
		ArrayResize(target, ArraySize(performance));
		ArrayCopy(target, performance);
	}

	void GetReturnsArray(double &target[]) {
		ArrayResize(target, ArraySize(returns));
		ArrayCopy(target, returns);
	}

	void GetOrdersHistory(SSOrderHistory &target[]) {
		ArrayResize(target, ArraySize(ordersHistory));

		for (int i = 0; i < ArraySize(ordersHistory); i++) {
			target[i] = ordersHistory[i];
		}
	}

	SSQualityResult GetQuality() {
		SSQualityResult result;

		int lastIndex = ArraySize(performance) - 1;
		double totalPerformance = (lastIndex >= 0) ? performance[lastIndex] : 0;

		if (totalPerformance <= 0) {
			result.quality = 0;
			result.reason = "Total performance is zero or negative";
			return result;
		}

		if (drawdownMaxInDollars <= DRAWDOWN_EPSILON) {
			result.quality = 0;
			result.reason = "Maximum drawdown is zero";
			return result;
		}

		result.quality = totalPerformance / drawdownMaxInDollars;
		result.reason = NULL;

		return result;
	}

	void OnCloseOrder(EOrder &order, EOrder &strategyOrders[]) {
		ArrayResize(lastClosedOrders, ArraySize(lastClosedOrders) + 1);
		lastClosedOrders[ArraySize(lastClosedOrders) - 1] = order;

		ArrayResize(ordersHistory, ArraySize(ordersHistory) + 1);
		ordersHistory[ArraySize(ordersHistory) - 1] = order.GetSnapshot();

		updateDrawdownWithFloatingPnL(strategyOrders);
	}

	void OnForceEnd() {
		processPendingOrders();
	}

	void OnOpenOrder(EOrder &order, EOrder &strategyOrders[]) {
		if (order.GetStatus() == ORDER_STATUS_CANCELLED) {
			return;
		}

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

		if (realNav > navPeak) {
			navPeak = realNav;
		}

		updateDrawdownWithFloatingPnL(strategyOrders);

		dailyPerformance = realNav - navYesterday;
		navYesterday = realNav;

		ArrayResize(returns, ArraySize(returns) + 1);
		returns[ArraySize(returns) - 1] = dailyPerformance;
	}

	void OnStartHour() {
	}

	SSStatisticsSnapshot GetDailySnapshot() {
		processPendingOrders();
		SSQualityResult quality = GetQuality();
		SSStatisticsSnapshot snapshotData = buildSnapshotData(quality);
		ArrayResize(snapshotData.orders, 0);
		return snapshotData;
	}

	void RestoreState(SStatisticsState &state) {
		startTime = state.startTime;
		navPeak = state.navPeak;
		navYesterday = state.navYesterday;
		drawdownMaxInDollars = state.drawdownMaxInDollars;
		drawdownMaxInPercentage = state.drawdownMaxInPercentage;

		ArrayResize(nav, ArraySize(state.nav));
		ArrayCopy(nav, state.nav);

		ArrayResize(performance, ArraySize(state.performance));
		ArrayCopy(performance, state.performance);

		ArrayResize(returns, ArraySize(state.returns));
		ArrayCopy(returns, state.returns);

		ArrayResize(ordersHistory, ArraySize(state.ordersHistory));
		for (int i = 0; i < ArraySize(state.ordersHistory); i++) {
			ordersHistory[i] = state.ordersHistory[i];
		}

		if (ArraySize(nav) > 0) {
			dailyPerformance = nav[ArraySize(nav) - 1] - navYesterday;
		}
	}
};

#endif
