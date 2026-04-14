#ifndef __ORDER_HISTORY_TRACKER_MQH__
#define __ORDER_HISTORY_TRACKER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../structs/SSOrderHistory.mqh"

class OrderHistoryTracker {
private:
	SSOrderHistory ordersHistory[];
	EOrder lastClosedOrders[];
	double todayClosedPnl;

public:
	OrderHistoryTracker() {
		todayClosedPnl = 0.0;
	}

	void RegisterClose(EOrder &order) {
		ArrayResize(lastClosedOrders, ArraySize(lastClosedOrders) + 1);
		lastClosedOrders[ArraySize(lastClosedOrders) - 1] = order;

		ArrayResize(ordersHistory, ArraySize(ordersHistory) + 1);
		ordersHistory[ArraySize(ordersHistory) - 1] = order.GetSnapshot();

		todayClosedPnl += order.GetProfitInDollars();
	}

	bool HasPending() const {
		return ArraySize(lastClosedOrders) > 0;
	}

	double GetPendingClosedProfit() const {
		double pending = 0.0;

		for (int i = 0; i < ArraySize(lastClosedOrders); i++) {
			pending += lastClosedOrders[i].GetProfitInDollars();
		}

		return pending;
	}

	double ConsumePendingClosedProfit() {
		double pending = GetPendingClosedProfit();
		ArrayResize(lastClosedOrders, 0);
		return pending;
	}

	double GetTodayClosedPnl() const {
		return todayClosedPnl;
	}

	void ResetTodayClosedPnl() {
		todayClosedPnl = 0.0;
	}

	void CopyOrdersHistory(SSOrderHistory &target[]) const {
		ArrayResize(target, ArraySize(ordersHistory));

		for (int i = 0; i < ArraySize(ordersHistory); i++) {
			target[i] = ordersHistory[i];
		}
	}

	void Restore(SSOrderHistory &restoredHistory[]) {
		ArrayResize(ordersHistory, ArraySize(restoredHistory));

		for (int i = 0; i < ArraySize(restoredHistory); i++) {
			ordersHistory[i] = restoredHistory[i];
		}

		ArrayResize(lastClosedOrders, 0);
		todayClosedPnl = 0.0;
	}
};

#endif
