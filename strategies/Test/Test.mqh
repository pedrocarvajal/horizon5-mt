#ifndef __STRATEGY_TEST_MQH__
#define __STRATEGY_TEST_MQH__

#include "../Strategy.mqh"
#include "../../structs/SQualityThresholds.mqh"

class Test:
public SEStrategy {
private:
	double takeProfitPoints;
	double stopLossPoints;
	ENUM_ORDER_TYPE orderSide;
	int entryHour;
	int lastOrderDay;

	int OnInit() {
		SEStrategy::OnInit();
		return INIT_SUCCEEDED;
	}

	void OnStartHour() {
		SEStrategy::OnStartHour();

		MqlDateTime currentTime = dtime.Now();

		if (currentTime.hour == entryHour && currentTime.day_of_year != lastOrderDay) {
			OpenDailyOrder();
			lastOrderDay = currentTime.day_of_year;
		}
	}

	void OpenDailyOrder() {
		double orderLotSize = GetLotSizeByCapital();

		if (orderLotSize <= 0) {
			logger.warning("Invalid lot size, skipping order");
			return;
		}

		double currentPrice = (orderSide == ORDER_TYPE_BUY)
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);

		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

		double takeProfitPrice = 0;
		double stopLossPrice = 0;

		if (orderSide == ORDER_TYPE_BUY) {
			takeProfitPrice = currentPrice + (takeProfitPoints * point);
			stopLossPrice = currentPrice - (stopLossPoints * point);
		} else {
			takeProfitPrice = currentPrice - (takeProfitPoints * point);
			stopLossPrice = currentPrice + (stopLossPoints * point);
		}

		EOrder *order = OpenNewOrder(
			orderSide,
			currentPrice,
			orderLotSize,
			true,
			false,
			takeProfitPrice,
			stopLossPrice);

		if (order == NULL) {
			logger.error("Failed to create order");
			return;
		}

		logger.info(StringFormat(
				    "Daily order created: %s %.2f lots @ %.5f | TP: %.5f | SL: %.5f",
				    (orderSide == ORDER_TYPE_BUY) ? "BUY" : "SELL",
				    orderLotSize,
				    currentPrice,
				    takeProfitPrice,
				    stopLossPrice));
	}

public:
	Test() {
		SetName("Test");
		SetPrefix("TST");

		takeProfitPoints = 500;
		stopLossPoints = 250;
		orderSide = ORDER_TYPE_BUY;
		entryHour = 10;
		lastOrderDay = -1;
	}
};

#endif
// Test modification $(date) git add -A
