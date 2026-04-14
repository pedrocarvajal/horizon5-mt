#ifndef __SE_STATISTICS_MQH__
#define __SE_STATISTICS_MQH__

#include "../../structs/SSOrderHistory.mqh"
#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SSQualityResult.mqh"
#include "../../structs/SStatisticsState.mqh"

#include "../SEDateTime/SEDateTime.mqh"

#include "../../entities/EOrder.mqh"

#include "components/NavTracker.mqh"
#include "components/PerformanceTracker.mqh"
#include "components/DrawdownTracker.mqh"
#include "components/OrderHistoryTracker.mqh"

#include "helpers/HCalculateFloatingPnl.mqh"
#include "helpers/HCalculateQuality.mqh"
#include "helpers/HBuildStatisticsSnapshot.mqh"

extern SEDateTime dtime;

class SEStatistics {
private:
	string id;
	datetime startTime;
	double initialBalance;

	NavTracker navTracker;
	PerformanceTracker performanceTracker;
	DrawdownTracker drawdownTracker;
	OrderHistoryTracker orderHistoryTracker;

	void processPendingOrders() {
		if (!orderHistoryTracker.HasPending()) {
			return;
		}

		double pending = orderHistoryTracker.ConsumePendingClosedProfit();
		performanceTracker.ApplyPendingProfit(pending);
	}

	void updateDrawdownWithFloatingPnl(EOrder &strategyOrders[]) {
		double realNav = initialBalance
				 + performanceTracker.GetLatest()
				 + orderHistoryTracker.GetPendingClosedProfit()
				 + CalculateFloatingPnl(strategyOrders);
		drawdownTracker.Update(navTracker.GetPeak(), realNav);
	}

public:
	SEStatistics(double allocatedBalance) {
		initialBalance = allocatedBalance;

		id = TimeToString(dtime.Now().timestamp, TIME_DATE | TIME_SECONDS);
		startTime = dtime.Now().timestamp;

		navTracker.Initialize(allocatedBalance);
	}

	double GetClosedNav() {
		return initialBalance
		       + performanceTracker.GetLatest()
		       + orderHistoryTracker.GetPendingClosedProfit();
	}

	SSStatisticsSnapshot GetDailySnapshot() {
		processPendingOrders();
		SSQualityResult quality = GetQuality();
		SSStatisticsSnapshot snapshotData = BuildStatisticsSnapshot(
			id,
			dtime.Now().timestamp,
			GetPointer(navTracker),
			GetPointer(performanceTracker),
			GetPointer(drawdownTracker),
			GetPointer(orderHistoryTracker),
			quality
		);
		ArrayResize(snapshotData.orders, 0);
		return snapshotData;
	}

	double GetDrawdownMaxInDollars() {
		return drawdownTracker.GetMaxInDollars();
	}

	double GetDrawdownMaxInPercentage() {
		return drawdownTracker.GetMaxInPercentage();
	}

	double GetInitialBalance() {
		return initialBalance;
	}

	double GetNav() {
		return navTracker.GetLatest();
	}

	void GetNavArray(double &target[]) {
		navTracker.CopyNav(target);
	}

	double GetNavPeak() {
		return navTracker.GetPeak();
	}

	double GetNavYesterday() {
		return navTracker.GetYesterday();
	}

	void GetOrdersHistory(SSOrderHistory &target[]) {
		orderHistoryTracker.CopyOrdersHistory(target);
	}

	void GetPerformanceArray(double &target[]) {
		performanceTracker.CopyPerformance(target);
	}

	SSQualityResult GetQuality() {
		return CalculateQuality(performanceTracker.GetLatest(), drawdownTracker.GetMaxInDollars());
	}

	void GetReturnsArray(double &target[]) {
		performanceTracker.CopyReturns(target);
	}

	datetime GetStartTime() {
		return startTime;
	}

	double GetTodayClosedPnl() {
		return orderHistoryTracker.GetTodayClosedPnl();
	}

	double GetTodayTotalPnl(EOrder &strategyOrders[]) {
		return orderHistoryTracker.GetTodayClosedPnl() + CalculateFloatingPnl(strategyOrders);
	}

	void OnCloseOrder(EOrder &order, EOrder &strategyOrders[]) {
		orderHistoryTracker.RegisterClose(order);
		updateDrawdownWithFloatingPnl(strategyOrders);
	}

	void OnForceEnd() {
		processPendingOrders();
	}

	void OnOpenOrder(EOrder &order, EOrder &strategyOrders[]) {
		if (order.GetStatus() == ORDER_STATUS_CANCELLED) {
			return;
		}

		updateDrawdownWithFloatingPnl(strategyOrders);
	}

	void OnStartDay(EOrder &strategyOrders[]) {
		processPendingOrders();
		orderHistoryTracker.ResetTodayClosedPnl();

		performanceTracker.StartNewDay();

		double prevPerformance = performanceTracker.GetLatest();
		double floatingPnl = CalculateFloatingPnl(strategyOrders);
		double closedNav = initialBalance + prevPerformance;
		double realNav = closedNav + floatingPnl;

		navTracker.AppendDay(realNav);

		updateDrawdownWithFloatingPnl(strategyOrders);

		performanceTracker.AppendReturn(navTracker.GetDailyPerformance());
	}

	void OnStartHour() {
	}

	void RestoreState(SStatisticsState &state) {
		startTime = state.startTime;

		navTracker.Restore(state.nav, state.navPeak, state.navYesterday);
		performanceTracker.Restore(state.performance, state.returns);
		drawdownTracker.Restore(state.drawdownMaxInDollars, state.drawdownMaxInPercentage);
		orderHistoryTracker.Restore(state.ordersHistory);
	}
};

#endif
