#ifndef __ORDER_OPENER_MQH__
#define __ORDER_OPENER_MQH__

#include "../../../adapters/ATrade.mqh"

#include "../../../constants/COOrder.mqh"

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../helpers/HIsMarketClosed.mqh"
#include "../../../helpers/HResolveTransientDefer.mqh"
#include "../../../helpers/HTradeRetcodeToLogCode.mqh"
#include "../helpers/HBuildOrderComment.mqh"
#include "../helpers/HResolveOrderTypeAndPrice.mqh"

#include "../../../interfaces/IStrategy.mqh"

#include "../../SEDateTime/SEDateTime.mqh"
#include "../../SEDateTime/structs/SDateTime.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../structs/SResolvedOrder.mqh"

#include "../validators/OrderValidator.mqh"

#include "OrderFinalizer.mqh"

extern SEDateTime dtime;

class OrderOpener {
private:
	SELogger logger;
	string symbol;
	ulong magicNumber;
	ATrade *trade;
	OrderValidator *validator;
	OrderFinalizer *finalizer;
	IStrategy *listener;

public:
	OrderOpener() {
		logger.SetPrefix("OrderBook::Opener");
		trade = NULL;
		validator = NULL;
		finalizer = NULL;
		listener = NULL;
		magicNumber = 0;
	}

	void Initialize(
		string orderSymbol,
		ulong orderMagicNumber,
		ATrade *tradeRef,
		OrderValidator *validatorRef,
		OrderFinalizer *finalizerRef
	) {
		symbol = orderSymbol;
		magicNumber = orderMagicNumber;
		trade = tradeRef;
		validator = validatorRef;
		finalizer = finalizerRef;
	}

	void SetListener(IStrategy *listenerRef) {
		listener = listenerRef;
	}

	void CheckToOpen(EOrder &order) {
		if (!order.IsPendingToOpen() || order.IsProcessed()) {
			return;
		}

		datetime currentTime = dtime.Timestamp();
		SOrderRetryState retry = order.GetOpenRetry();

		if (retry.after > 0 && currentTime < retry.after) {
			return;
		}

		if (retry.count >= MAX_RETRY_COUNT_OPEN) {
			logger.Error(LOG_CODE_ORDER_RETRY_EXHAUSTED, StringFormat(
				"order retry exhausted | symbol=%s order_id=%s retry=%d reason='max open retries reached'",
				symbol,
				order.GetId(),
				retry.count
			));
			finalizer.FinalizeCancelled(order);
			return;
		}

		logger.Info(LOG_CODE_ORDER_OPEN_QUEUED, StringFormat(
			"order opening | symbol=%s order_id=%s",
			symbol,
			order.GetId()
		));
		Open(order);
	}

	void Open(EOrder &order) {
		SMarketStatus marketStatus = GetMarketStatus(symbol);

		if (marketStatus.isClosed) {
			SOrderRetryState retry = order.GetOpenRetry();
			if (retry.retryable) {
				retry.after = dtime.Timestamp() + marketStatus.opensInSeconds;
				order.SetOpenRetry(retry);
				logger.Warning(LOG_CODE_ORDER_RETRY_SCHEDULED, StringFormat(
					"open retry scheduled | symbol=%s order_id=%s reason='market closed' retry_in_s=%d",
					symbol,
					order.GetId(),
					marketStatus.opensInSeconds
				));
				return;
			}

			logger.Warning(LOG_CODE_ORDER_OPEN_FAILED, StringFormat(
				"order open dropped | symbol=%s order_id=%s reason='market closed'",
				symbol,
				order.GetId()
			));
			finalizer.FinalizeCancelled(order);
			return;
		}

		if (CheckPointer(validator) == POINTER_INVALID || !validator.ValidateOrder(order)) {
			finalizer.FinalizeCancelled(order);
			return;
		}

		SResolvedOrder resolved = ResolveOrderTypeAndPrice(order, symbol);

		STradeResult result = trade.Open(
			symbol,
			BuildOrderComment(order, symbol),
			resolved.type,
			resolved.price,
			order.GetVolume(),
			order.GetTakeProfitPrice(),
			order.GetStopLossPrice(),
			magicNumber
		);

		HandleOpenResult(order, result);
	}

	void HandleOpenResult(EOrder &order, STradeResult &result) {
		if (result.severity == TRADE_SEVERITY_SUCCESS) {
			bool wasPending = (order.GetStatus() == ORDER_STATUS_PENDING);
			applyOpenedFields(order, result);

			if (order.GetDealId() == 0) {
				finalizeAsPending(order);
			} else {
				finalizeAsOpen(order, wasPending);
			}

			order.BuildSnapshot();
			finalizer.Persist(order);
			return;
		}

		if (result.severity == TRADE_SEVERITY_TRANSIENT) {
			SOrderRetryState retry = order.GetOpenRetry();
			if (!retry.retryable) {
				logger.Warning(GetTradeRetcodeLogCode(result.retcode), StringFormat(
					"order open dropped | symbol=%s order_id=%s reason='%s'",
					symbol,
					order.GetId(),
					ATrade::DescribeRetcode(result.retcode)
				));
				finalizer.FinalizeCancelled(order);
				return;
			}

			int deferSeconds = ResolveTransientDeferSeconds(result.retcode, symbol);
			retry.after = dtime.Timestamp() + deferSeconds;
			order.SetOpenRetry(retry);
			logger.Warning(GetTradeRetcodeLogCode(result.retcode), StringFormat(
				"open retry scheduled | symbol=%s order_id=%s reason='%s' retry_in_s=%d",
				symbol,
				order.GetId(),
				ATrade::DescribeRetcode(result.retcode),
				deferSeconds
			));
			return;
		}

		handleOpenFailure(order, result);
	}

private:
	void handleOpenFailure(EOrder &order, STradeResult &result) {
		SOrderRetryState retry = order.GetOpenRetry();
		retry.count += 1;
		order.SetOpenRetry(retry);
		logger.Error(GetTradeRetcodeLogCode(result.retcode), StringFormat(
			"order open failed | symbol=%s order_id=%s retry=%d error=%d reason='%s'",
			symbol,
			order.GetId(),
			retry.count,
			result.retcode,
			ATrade::DescribeRetcode(result.retcode)
		));

		if (retry.count >= MAX_RETRY_COUNT_OPEN) {
			finalizer.FinalizeCancelled(order);
		}
	}

	void applyOpenedFields(EOrder &order, STradeResult &result) {
		order.SetIsProcessed(true);
		order.SetPendingToOpen(false);
		SOrderRetryState retry = order.GetOpenRetry();
		retry.Reset();
		order.SetOpenRetry(retry);
		SDateTime openTime = dtime.Now();
		order.SetOpenAt(openTime);
		order.SetOpenPrice(result.price);
		order.SetDealId(result.dealId);
		order.SetOrderId(result.orderId);

		if (order.GetDealId() > 0) {
			HistoryDealSelect(order.GetDealId());
			order.SetPositionId(HistoryDealGetInteger(order.GetDealId(), DEAL_POSITION_ID));
		}
	}

	void finalizeAsPending(EOrder &order) {
		order.SetStatus(ORDER_STATUS_PENDING);
		logger.Info(LOG_CODE_ORDER_OPEN_PENDING, StringFormat(
			"order opened as pending | symbol=%s order_id=%s order_ticket=%llu",
			symbol,
			order.GetId(),
			order.GetOrderId()
		));

		if (CheckPointer(listener) != POINTER_INVALID) {
			listener.OnPendingOrderPlaced(order);
		}
	}

	void finalizeAsOpen(EOrder &order, bool wasPending) {
		logger.Success(LOG_CODE_ORDER_OPENED, StringFormat(
			"order opened | symbol=%s order_id=%s position_id=%llu deal_id=%llu transition=%s",
			symbol,
			order.GetId(),
			order.GetPositionId(),
			order.GetDealId(),
			wasPending ? "from_pending" : "immediate"
		));

		order.SetStatus(ORDER_STATUS_OPEN);
	}
};

#endif
