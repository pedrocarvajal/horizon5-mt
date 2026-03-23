#ifndef __MONITOR_ORDER_RESOURCE_MQH__
#define __MONITOR_ORDER_RESOURCE_MQH__

#include "../../../services/SEDateTime/structs/SDateTime.mqh"

#include "../../../helpers/HClampNumeric.mqh"

#include "../../../entities/EOrder.mqh"

#include "../HorizonMonitorContext.mqh"
#include "../../../helpers/HGetOrderStatus.mqh"
#include "../../../helpers/HGetOrderSide.mqh"
#include "../../../helpers/HGetCloseReason.mqh"
#include "../../../helpers/HGetOrderUuid.mqh"
#include "StrategyResource.mqh"
#include "AssetResource.mqh"

#define VALID_TIMESTAMP_MIN 1577836800
#define VALID_TIMESTAMP_MAX 4102444800

class OrderResource {
private:
	HorizonMonitorContext * context;
	StrategyResource *strategies;
	AssetResource *assets;

	bool isValidTimestamp(datetime ts) {
		long value = (long)ts;
		return value > VALID_TIMESTAMP_MIN && value < VALID_TIMESTAMP_MAX;
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
		datetime signalTimestamp = order.GetSignalAt().timestamp;
		datetime openTimestamp = order.GetOpenAt().timestamp;
		datetime closeTimestamp = order.GetCloseAt().timestamp;

		if (isValidTimestamp(signalTimestamp)) {
			body.setProperty("signal_at", (long)signalTimestamp);
		}

		if (isValidTimestamp(openTimestamp)) {
			body.setProperty("opened_at", (long)openTimestamp);
		}

		if (isValidTimestamp(closeTimestamp)) {
			body.setProperty("closed_at", (long)closeTimestamp);
		}
	}

public:
	OrderResource(HorizonMonitorContext * ctx, StrategyResource * strat, AssetResource * ast) {
		context = ctx;
		strategies = strat;
		assets = ast;
	}

	void Upsert(EOrder &order) {
		string orderUuid = GetDeterministicOrderUuid(
			context.GetAccountNumber(),
			context.GetBrokerServer(),
			order.GetSymbol(),
			order.GetMagicNumber(),
			order.GetOrderId(),
			order.GetPositionId()
		);

		JSON::Object body;
		body.setProperty("id", orderUuid);
		body.setProperty("account_id", context.GetAccountUuid());
		body.setProperty("strategy_id", strategies.GetUuid(order.GetMagicNumber()));
		body.setProperty("deal_id", (long)order.GetDealId());
		body.setProperty("order_id", (long)order.GetOrderId());
		body.setProperty("position_id", (long)order.GetPositionId());
		body.setProperty("source", order.GetSource());
		body.setProperty("asset_id", assets.GetUuid(order.GetSymbol()));
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

		context.Post("api/v1/order", body);
	}
};

#endif
