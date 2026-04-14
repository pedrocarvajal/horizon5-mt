#ifndef __H_DESERIALIZE_ORDER_MQH__
#define __H_DESERIALIZE_ORDER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../libraries/Json/index.mqh"

#include "../../../structs/SOrderRetryState.mqh"

#include "../../SEDateTime/SEDateTime.mqh"
#include "../../SEDateTime/structs/SDateTime.mqh"

extern SEDateTime dtime;

bool DeserializeOrder(JSON::Object *json, EOrder &order) {
	if (json == NULL || !json.hasValue("_id")) {
		return false;
	}

	order.SetIsInitialized(json.getBoolean("is_initialized"));
	order.SetIsProcessed(json.getBoolean("is_processed"));
	order.SetIsMarketOrder(json.getBoolean("is_market_order"));
	order.SetPendingToOpen(json.getBoolean("pending_to_open"));
	order.SetPendingToClose(json.getBoolean("pending_to_close"));

	order.SetStatus((ENUM_ORDER_STATUSES)json.getNumber("status"));

	SOrderRetryState openRetry;
	openRetry.retryable = json.getBoolean("retryable_on_open");
	openRetry.count = (int)json.getNumber("retry_count_open");
	openRetry.after = (datetime)json.getNumber("retry_after_open");
	order.SetOpenRetry(openRetry);

	SOrderRetryState cancelRetry;
	cancelRetry.retryable = json.getBoolean("retryable_on_cancel");
	cancelRetry.count = (int)json.getNumber("retry_count_cancel");
	cancelRetry.after = (datetime)json.getNumber("retry_after_cancel");
	order.SetCancelRetry(cancelRetry);

	SOrderRetryState closeRetry;
	closeRetry.retryable = json.getBoolean("retryable_on_close");
	closeRetry.count = (int)json.getNumber("retry_count_close");
	closeRetry.after = (datetime)json.getNumber("retry_after_close");
	order.SetCloseRetry(closeRetry);

	SOrderRetryState modifyRetry;
	modifyRetry.retryable = json.getBoolean("retryable_on_modify");
	modifyRetry.count = (int)json.getNumber("retry_count_modify");
	modifyRetry.after = (datetime)json.getNumber("retry_after_modify");
	order.SetModifyRetry(modifyRetry);

	order.SetId(json.getString("_id"));
	order.SetSource(json.getString("source"));
	order.SetSymbol(json.getString("symbol"));
	order.SetMagicNumber((ulong)json.getNumber("magic_number"));
	order.SetSide((int)json.getNumber("side"));
	order.SetOrderId((ulong)json.getNumber("order_id"));
	order.SetDealId((ulong)json.getNumber("deal_id"));
	order.SetPositionId((ulong)json.getNumber("position_id"));

	order.SetVolume(json.getNumber("volume"));
	order.SetSignalPrice(json.getNumber("signal_price"));
	order.SetOpenAtPrice(json.getNumber("open_at_price"));
	order.SetOpenPrice(json.getNumber("open_price"));
	order.SetTakeProfitPrice(json.getNumber("take_profit_price"));
	order.SetStopLossPrice(json.getNumber("stop_loss_price"));

	order.SetClosePrice(json.getNumber("close_price"));
	order.SetProfitInDollars(json.getNumber("profit_in_dollars"));
	order.SetCloseReason((ENUM_DEAL_REASON)(int)json.getNumber("order_close_reason"));

	SDateTime signalAt = dtime.FromTimestamp((datetime)json.getNumber("signal_at"));
	SDateTime openAt = dtime.FromTimestamp((datetime)json.getNumber("open_at"));
	SDateTime closeAt = dtime.FromTimestamp((datetime)json.getNumber("close_at"));
	order.SetSignalAt(signalAt);
	order.SetOpenAt(openAt);
	order.SetCloseAt(closeAt);

	return true;
}

#endif
