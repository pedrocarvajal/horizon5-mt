#ifndef __ORDER_RESOURCE_MQH__
#define __ORDER_RESOURCE_MQH__

#include "../../../services/SEDateTime/structs/SDateTime.mqh"

#include "../../../helpers/HClampNumeric.mqh"

#include "../../../entities/EOrder.mqh"

#include "../HorizonAPIContext.mqh"
#include "../helpers/HGetOrderStatus.mqh"
#include "../helpers/HGetOrderSide.mqh"
#include "../helpers/HGetCloseReason.mqh"
#include "StrategyResource.mqh"

#define VALID_ORDER_YEAR_MIN 2020
#define VALID_ORDER_YEAR_MAX 2100

class OrderResource {
private:
	HorizonAPIContext * context;
	StrategyResource *strategies;

	bool isValidDateTime(SDateTime &dt) {
		return dt.timestamp > 0 && dt.year >= VALID_ORDER_YEAR_MIN && dt.year <= VALID_ORDER_YEAR_MAX;
	}

	void buildProfitFields(JSON::Object &body, EOrder &order) {
		if (order.GetStatus() == ORDER_STATUS_CLOSED) {
			body.setProperty("profit", ClampNumeric(order.GetProfitInDollars(), 13, 2));
			body.setProperty("gross_profit", ClampNumeric(order.GetGrossProfit(), 13, 2));
			body.setProperty("commission", ClampNumeric(order.GetCommission(), 13, 2));
			body.setProperty("swap", ClampNumeric(order.GetSwap(), 13, 2));
			body.setProperty("close_reason", GetCloseReason(order.GetCloseReason()));
		} else {
			body.setProperty("profit", ClampNumeric(order.GetFloatingPnL(), 13, 2));
		}
	}

	void buildDateTimeFields(JSON::Object &body, EOrder &order) {
		SDateTime signalTime = order.GetSignalAt();
		SDateTime openTime = order.GetOpenAt();
		SDateTime closeTime = order.GetCloseAt();

		if (isValidDateTime(signalTime)) {
			body.setProperty("signal_at", signalTime.ToUTCISO());
		}

		if (isValidDateTime(openTime)) {
			body.setProperty("opened_at", openTime.ToUTCISO());
		}

		if (isValidDateTime(closeTime)) {
			body.setProperty("closed_at", closeTime.ToUTCISO());
		}
	}

public:
	OrderResource(HorizonAPIContext * ctx, StrategyResource * strat) {
		context = ctx;
		strategies = strat;
	}

	void Upsert(EOrder &order) {
		JSON::Object body;
		body.setProperty("id", order.GetId());
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("strategy_id", strategies.GetUUID(order.GetMagicNumber()));
		body.setProperty("ticket", (long)order.GetOrderId());
		body.setProperty("deal_id", (long)order.GetDealId());
		body.setProperty("position_id", (long)order.GetPositionId());
		body.setProperty("source", order.GetSource());
		body.setProperty("symbol", order.GetSymbol());
		body.setProperty("side", GetOrderSide(order.GetSide()));
		body.setProperty("status", GetOrderStatus(order.GetStatus()));
		body.setProperty("is_market_order", order.IsMarketOrder());
		body.setProperty("volume", ClampNumeric(order.GetVolume(), 6, 4));
		body.setProperty("signal_price", ClampNumeric(order.GetSignalPrice(), 10, 5));
		body.setProperty("open_at_price", ClampNumeric(order.GetOpenAtPrice(), 10, 5));
		body.setProperty("open_price", ClampNumeric(order.GetOpenPrice(), 10, 5));
		body.setProperty("close_price", ClampNumeric(order.GetClosePrice(), 10, 5));
		body.setProperty("take_profit", ClampNumeric(order.GetTakeProfitPrice(), 10, 5));
		body.setProperty("stop_loss", ClampNumeric(order.GetStopLossPrice(), 10, 5));
		buildProfitFields(body, order);
		buildDateTimeFields(body, order);

		context.Post("api/v1/order/", body);
	}
};

#endif
