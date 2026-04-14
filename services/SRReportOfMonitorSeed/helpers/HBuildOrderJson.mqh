#ifndef __H_BUILD_ORDER_JSON_MQH__
#define __H_BUILD_ORDER_JSON_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../libraries/Json/index.mqh"

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetOrderSide.mqh"
#include "../../../helpers/HGetOrderStatus.mqh"
#include "../../../helpers/HGetCloseReason.mqh"

#include "HIsValidMonitorSeedTimestamp.mqh"

JSON::Object *BuildOrderJson(
	EOrder &order,
	string orderUuid,
	string accountUuid,
	string strategyUuid,
	string assetUuid
) {
	JSON::Object *obj = new JSON::Object();
	obj.setProperty("id", orderUuid);
	obj.setProperty("account_id", accountUuid);
	obj.setProperty("strategy_id", strategyUuid);
	obj.setProperty("asset_id", assetUuid);
	obj.setProperty("deal_id", (long)order.GetDealId());
	obj.setProperty("order_id", (long)order.GetOrderId());
	obj.setProperty("position_id", (long)order.GetPositionId());
	obj.setProperty("source", order.GetSource());
	obj.setProperty("side", GetOrderSide(order.GetSide()));
	obj.setProperty("status", GetOrderStatus(order.GetStatus()));
	obj.setProperty("is_market_order", order.IsMarketOrder());
	obj.setProperty("volume", ClampNumeric(order.GetVolume(), 6, 4));
	obj.setProperty("signal_price", ClampNumeric(order.GetSignalPrice(), 10, 5));
	obj.setProperty("open_at_price", ClampNumeric(order.GetOpenAtPrice(), 10, 5));
	obj.setProperty("open_price", ClampNumeric(order.GetOpenPrice(), 10, 5));
	obj.setProperty("close_price", ClampNumeric(order.GetClosePrice(), 10, 5));
	obj.setProperty("take_profit", ClampNumeric(order.GetTakeProfitPrice(), 10, 5));
	obj.setProperty("stop_loss", ClampNumeric(order.GetStopLossPrice(), 10, 5));
	obj.setProperty("profit", ClampNumeric(order.GetProfitInDollars(), 13, 2));
	obj.setProperty("gross_profit", ClampNumeric(order.GetGrossProfit(), 13, 2));
	obj.setProperty("commission", ClampNumeric(order.GetCommission(), 13, 2));
	obj.setProperty("swap", ClampNumeric(order.GetSwap(), 13, 2));
	obj.setProperty("close_reason", GetCloseReason(order.GetCloseReason()));

	long signalAt = (long)order.GetSignalAt().timestamp;
	long openedAt = (long)order.GetOpenAt().timestamp;
	long closedAt = (long)order.GetCloseAt().timestamp;

	if (IsValidMonitorSeedTimestamp(signalAt)) {
		obj.setProperty("signal_at", signalAt);
	}

	if (IsValidMonitorSeedTimestamp(openedAt)) {
		obj.setProperty("opened_at", openedAt);
	}

	if (IsValidMonitorSeedTimestamp(closedAt)) {
		obj.setProperty("closed_at", closedAt);
	}

	return obj;
}

#endif
