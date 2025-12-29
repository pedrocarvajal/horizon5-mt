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
		double lotSize = GetLotSizeByCapital();

		if (lotSize <= 0) {
			logger.warning("Invalid lot size, skipping order");
			return;
		}

		double currentPrice = (orderSide == ORDER_TYPE_BUY)
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);

		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

		EOrder *order = OpenNewOrder(
			orderSide,
			currentPrice,
			lotSize,
			true);

		if (order == NULL) {
			logger.error("Failed to create order");
			return;
		}

		if (orderSide == ORDER_TYPE_BUY) {
			order.mainTakeProfitAtPrice = currentPrice + (takeProfitPoints * point);
			order.mainStopLossAtPrice = currentPrice - (stopLossPoints * point);
		} else {
			order.mainTakeProfitAtPrice = currentPrice - (takeProfitPoints * point);
			order.mainStopLossAtPrice = currentPrice + (stopLossPoints * point);
		}

		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = order;

		logger.info(StringFormat(
				    "Daily order created: %s %.2f lots @ %.5f | TP: %.5f | SL: %.5f",
				    (orderSide == ORDER_TYPE_BUY) ? "BUY" : "SELL",
				    lotSize,
				    currentPrice,
				    order.mainTakeProfitAtPrice,
				    order.mainStopLossAtPrice));
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
