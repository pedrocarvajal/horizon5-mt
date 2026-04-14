#ifndef __H_SERIALIZE_ORDER_MQH__
#define __H_SERIALIZE_ORDER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../libraries/Json/index.mqh"

#include "../../../structs/SOrderRetryState.mqh"

#include "../../SEDateTime/SEDateTime.mqh"

extern SEDateTime dtime;

JSON::Object *SerializeOrder(EOrder &order) {
	JSON::Object *json = new JSON::Object();

	json.setProperty("_id", order.GetId());
	json.setProperty("is_initialized", order.IsInitialized());
	json.setProperty("is_processed", order.IsProcessed());
	json.setProperty("is_market_order", order.IsMarketOrder());
	json.setProperty("pending_to_open", order.IsPendingToOpen());
	json.setProperty("pending_to_close", order.IsPendingToClose());

	SOrderRetryState openRetry = order.GetOpenRetry();
	SOrderRetryState cancelRetry = order.GetCancelRetry();
	SOrderRetryState closeRetry = order.GetCloseRetry();
	SOrderRetryState modifyRetry = order.GetModifyRetry();

	json.setProperty("retryable_on_open", openRetry.retryable);
	json.setProperty("retryable_on_cancel", cancelRetry.retryable);
	json.setProperty("retryable_on_close", closeRetry.retryable);
	json.setProperty("retryable_on_modify", modifyRetry.retryable);
	json.setProperty("retry_count_open", openRetry.count);
	json.setProperty("retry_count_cancel", cancelRetry.count);
	json.setProperty("retry_count_close", closeRetry.count);
	json.setProperty("retry_count_modify", modifyRetry.count);
	json.setProperty("retry_after_open", (long)openRetry.after);
	json.setProperty("retry_after_cancel", (long)cancelRetry.after);
	json.setProperty("retry_after_close", (long)closeRetry.after);
	json.setProperty("retry_after_modify", (long)modifyRetry.after);
	json.setProperty("status", (int)order.GetStatus());

	json.setProperty("source", order.GetSource());
	json.setProperty("symbol", order.GetSymbol());
	json.setProperty("magic_number", (long)order.GetMagicNumber());
	json.setProperty("side", order.GetSide());
	json.setProperty("order_id", (long)order.GetOrderId());
	json.setProperty("deal_id", (long)order.GetDealId());
	json.setProperty("position_id", (long)order.GetPositionId());

	json.setProperty("volume", order.GetVolume());
	json.setProperty("signal_price", order.GetSignalPrice());
	json.setProperty("open_at_price", order.GetOpenAtPrice());
	json.setProperty("open_price", order.GetOpenPrice());
	json.setProperty("take_profit_price", order.GetTakeProfitPrice());
	json.setProperty("stop_loss_price", order.GetStopLossPrice());

	json.setProperty("close_price", order.GetClosePrice());
	json.setProperty("profit_in_dollars", order.GetProfitInDollars());
	json.setProperty("order_close_reason", (int)order.GetCloseReason());

	json.setProperty("signal_at", (long)order.GetSignalAt().timestamp);
	json.setProperty("open_at", (long)order.GetOpenAt().timestamp);
	json.setProperty("close_at", (long)order.GetCloseAt().timestamp);
	json.setProperty("saved_at", (long)dtime.Timestamp());

	return json;
}

#endif
