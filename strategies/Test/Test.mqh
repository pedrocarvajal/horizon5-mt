#ifndef __STRATEGY_TEST_MQH__
#define __STRATEGY_TEST_MQH__

#include "../Strategy.mqh"
#include "../../structs/SQualityThresholds.mqh"

input group "Test Strategy Settings";
input double TestTakeProfitPoints = 500; // [TEST] > Take Profit (points)
input double TestStopLossPoints = 250; // [TEST] > Stop Loss (points)
input ENUM_ORDER_TYPE TestOrderSide = ORDER_TYPE_BUY; // [TEST] > Order Side
input int TestEntryHour = 10; // [TEST] > Entry Hour (0-23)

class Test:
public SEStrategy {
private:
	int lastOrderDay;

	int OnInit() {
		SEStrategy::OnInit();

		SetupQualityThresholds();

		return INIT_SUCCEEDED;
	}

	void OnStartHour() {
		SEStrategy::OnStartHour();

		MqlDateTime currentTime = dtime.Now();

		if (currentTime.hour == TestEntryHour && currentTime.day_of_year != lastOrderDay) {
			OpenDailyOrder();
			lastOrderDay = currentTime.day_of_year;
		}
	}

	void OpenDailyOrder() {
		double lotSize = GetLotSize();

		if (lotSize <= 0) {
			logger.warning("Invalid lot size, skipping order");
			return;
		}

		double currentPrice = (TestOrderSide == ORDER_TYPE_BUY)
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);

		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

		EOrder *order = OpenNewOrder(
			1,
			TestOrderSide,
			currentPrice,
			lotSize,
			true);

		if (order == NULL) {
			logger.error("Failed to create order");
			return;
		}

		if (TestOrderSide == ORDER_TYPE_BUY) {
			order.mainTakeProfitAtPrice = currentPrice + (TestTakeProfitPoints * point);
			order.mainStopLossAtPrice = currentPrice - (TestStopLossPoints * point);
		} else {
			order.mainTakeProfitAtPrice = currentPrice - (TestTakeProfitPoints * point);
			order.mainStopLossAtPrice = currentPrice + (TestStopLossPoints * point);
		}

		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = order;

		logger.info(StringFormat(
				    "Daily order created: %s %.2f lots @ %.5f | TP: %.5f | SL: %.5f",
				    (TestOrderSide == ORDER_TYPE_BUY) ? "BUY" : "SELL",
				    lotSize,
				    currentPrice,
				    order.mainTakeProfitAtPrice,
				    order.mainStopLossAtPrice));
	}

	void SetupQualityThresholds() {
		SQualityThresholds thresholds;

		thresholds.optimizationFormula = OPTIMIZATION_BY_PERFORMANCE;

		thresholds.expectedTotalReturnPctByMonth = 0.01;
		thresholds.expectedMaxDrawdownPct = 0.01;
		thresholds.expectedWinRate = 1;
		thresholds.expectedRecoveryFactor = 3;
		thresholds.expectedRiskRewardRatio = 1;
		thresholds.expectedRSquared = 0.95;
		thresholds.expectedTrades = 28;

		thresholds.minTotalReturnPct = 0.0;
		thresholds.maxMaxDrawdownPct = 0.30;
		thresholds.minWinRate = 0;
		thresholds.minRiskRewardRatio = 0;
		thresholds.minRecoveryFactor = 1;
		thresholds.minRSquared = 0.0;
		thresholds.minTrades = 5;

		SetQualityThresholds(thresholds);
	}

public:
	Test() {
		SetName("Test");
		SetPrefix("TST");
		SetMagicNumber(9999);

		lastOrderDay = -1;
	}
};

#endif
