#ifndef __ORDER_CANCELLER_MQH__
#define __ORDER_CANCELLER_MQH__

#include "../../../adapters/ATrade.mqh"

#include "../../../constants/COOrder.mqh"
#include "../../../constants/COTransientDefer.mqh"

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../helpers/HIsMarketClosed.mqh"
#include "../../../helpers/HResolveTransientDefer.mqh"
#include "../../../helpers/HTradeRetcodeToLogCode.mqh"

#include "../../../interfaces/IStrategy.mqh"

#include "../../../structs/SOrderRetryState.mqh"

#include "../../SEDateTime/SEDateTime.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../validators/OrderValidator.mqh"

#include "OrderFinalizer.mqh"

extern SEDateTime dtime;

class OrderCanceller {
private:
	SELogger logger;
	string symbol;
	ATrade *trade;
	OrderValidator *validator;
	OrderFinalizer *finalizer;
	IStrategy *listener;

public:
	OrderCanceller() {
		logger.SetPrefix("OrderBook::Canceller");
		trade = NULL;
		validator = NULL;
		finalizer = NULL;
		listener = NULL;
	}

	void Initialize(string orderSymbol, ATrade *tradeRef, OrderValidator *validatorRef, OrderFinalizer *finalizerRef) {
		symbol = orderSymbol;
		trade = tradeRef;
		validator = validatorRef;
		finalizer = finalizerRef;
	}

	void SetListener(IStrategy *listenerRef) {
		listener = listenerRef;
	}

	void CheckToCancel(EOrder &order) {
		datetime currentTime = dtime.Timestamp();
		SOrderRetryState retry = order.GetCancelRetry();

		if (retry.after > 0 && currentTime < retry.after) {
			return;
		}

		if (retry.count >= MAX_RETRY_COUNT_CANCEL) {
			logger.Error(LOG_CODE_ORDER_RETRY_EXHAUSTED, StringFormat(
				"order retry exhausted | symbol=%s order_id=%s retry=%d reason='max cancel retries reached'",
				symbol,
				order.GetId(),
				retry.count
			));
			finalizer.FinalizeCancelled(order);
			return;
		}

		Cancel(order);
	}

	void Cancel(EOrder &order) {
		SMarketStatus marketStatus = GetMarketStatus(symbol);

		if (marketStatus.isClosed) {
			SOrderRetryState retry = order.GetCancelRetry();
			if (retry.retryable) {
				retry.after = dtime.Timestamp() + marketStatus.opensInSeconds;
				order.SetCancelRetry(retry);
				logger.Warning(LOG_CODE_ORDER_RETRY_SCHEDULED, StringFormat(
					"cancel retry scheduled | symbol=%s order_id=%s reason='market closed' retry_in_s=%d",
					symbol,
					order.GetId(),
					marketStatus.opensInSeconds
				));
				return;
			}

			dropCancel(order, LOG_CODE_ORDER_CANCEL_FAILED, "market closed");
			return;
		}

		if (order.GetOrderId() == 0) {
			logger.Warning(LOG_CODE_ORDER_CANCEL_FAILED, StringFormat(
				"order cancel failed | symbol=%s order_id=%s reason='invalid order ticket'",
				symbol,
				order.GetId()
			));
			finalizer.FinalizeCancelled(order);
			return;
		}

		if (!OrderSelect(order.GetOrderId())) {
			logger.Info(LOG_CODE_ORDER_CANCELLED, StringFormat(
				"order cancelled | symbol=%s order_id=%s order_ticket=%llu reason='order no longer exists'",
				symbol,
				order.GetId(),
				order.GetOrderId()
			));
			finalizer.FinalizeCancelled(order);
			return;
		}

		if (CheckPointer(validator) == POINTER_INVALID || !validator.ValidatePendingCancel(order)) {
			SOrderRetryState retry = order.GetCancelRetry();
			if (!retry.retryable) {
				dropCancel(order, LOG_CODE_ORDER_CANCEL_FAILED, "validation failed");
				return;
			}

			retry.count += 1;
			retry.after = dtime.Timestamp() + CANCEL_VALIDATION_RETRY_DEFER_SECONDS;
			order.SetCancelRetry(retry);
			order.SetPendingToClose(true);
			logger.Warning(LOG_CODE_ORDER_RETRY_SCHEDULED, StringFormat(
				"cancel retry scheduled | symbol=%s order_id=%s retry=%d reason='validation failed' retry_in_s=%d",
				symbol,
				order.GetId(),
				retry.count,
				CANCEL_VALIDATION_RETRY_DEFER_SECONDS
			));
			return;
		}

		STradeResult result = trade.Cancel(order.GetOrderId());

		if (result.severity == TRADE_SEVERITY_SUCCESS) {
			logger.Info(LOG_CODE_ORDER_CANCEL_QUEUED, StringFormat(
				"order cancel queued | symbol=%s order_id=%s order_ticket=%llu",
				symbol,
				order.GetId(),
				order.GetOrderId()
			));
			order.SetStatus(ORDER_STATUS_CLOSING);
			order.SetPendingToOpen(false);
			order.SetPendingToClose(false);
			SOrderRetryState cleared = order.GetCancelRetry();
			cleared.Reset();
			order.SetCancelRetry(cleared);

			finalizer.Persist(order);

			if (CheckPointer(listener) != POINTER_INVALID) {
				listener.OnOrderUpdated(order);
			}
			return;
		}

		if (result.severity == TRADE_SEVERITY_TRANSIENT) {
			SOrderRetryState retry = order.GetCancelRetry();
			if (!retry.retryable) {
				dropCancel(order, GetTradeRetcodeLogCode(result.retcode), ATrade::DescribeRetcode(result.retcode));
				return;
			}

			int deferSeconds = ResolveTransientDeferSeconds(result.retcode, symbol);
			retry.after = dtime.Timestamp() + deferSeconds;
			order.SetCancelRetry(retry);
			order.SetPendingToClose(true);
			logger.Warning(GetTradeRetcodeLogCode(result.retcode), StringFormat(
				"cancel retry scheduled | symbol=%s order_id=%s reason='%s' retry_in_s=%d",
				symbol,
				order.GetId(),
				ATrade::DescribeRetcode(result.retcode),
				deferSeconds
			));
			return;
		}

		SOrderRetryState retry = order.GetCancelRetry();
		if (!retry.retryable) {
			logger.Error(GetTradeRetcodeLogCode(result.retcode), StringFormat(
				"order cancel dropped | symbol=%s order_id=%s order_ticket=%llu error=%d reason='%s'",
				symbol,
				order.GetId(),
				order.GetOrderId(),
				result.retcode,
				ATrade::DescribeRetcode(result.retcode)
			));
			order.SetPendingToClose(false);
			retry.Reset();
			order.SetCancelRetry(retry);
			return;
		}

		retry.count += 1;
		retry.after = dtime.Timestamp() + TRANSIENT_DEFER_DEFAULT_SECONDS;
		order.SetCancelRetry(retry);
		order.SetPendingToClose(true);
		logger.Error(GetTradeRetcodeLogCode(result.retcode), StringFormat(
			"order cancel failed | symbol=%s order_id=%s order_ticket=%llu retry=%d error=%d reason='%s'",
			symbol,
			order.GetId(),
			order.GetOrderId(),
			retry.count,
			result.retcode,
			ATrade::DescribeRetcode(result.retcode)
		));
	}

private:
	void dropCancel(EOrder &order, ENUM_LOG_CODE logCode, string reason) {
		SOrderRetryState retry = order.GetCancelRetry();
		retry.Reset();
		order.SetCancelRetry(retry);
		order.SetPendingToClose(false);
		logger.Warning(logCode, StringFormat(
			"order cancel dropped | symbol=%s order_id=%s reason='%s'",
			symbol,
			order.GetId(),
			reason
		));
	}
};

#endif
