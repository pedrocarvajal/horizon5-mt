#ifndef __ORDER_CLOSER_MQH__
#define __ORDER_CLOSER_MQH__

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
#include "../../SEDateTime/structs/SDateTime.mqh"

#include "../../SELogger/SELogger.mqh"

#include "OrderFinalizer.mqh"

extern SEDateTime dtime;

class OrderCloser {
private:
	SELogger logger;
	string symbol;
	ATrade *trade;
	OrderFinalizer *finalizer;
	IStrategy *listener;

public:
	OrderCloser() {
		logger.SetPrefix("OrderBook::Closer");
		trade = NULL;
		finalizer = NULL;
		listener = NULL;
	}

	void Initialize(string orderSymbol, ATrade *tradeRef, OrderFinalizer *finalizerRef) {
		symbol = orderSymbol;
		trade = tradeRef;
		finalizer = finalizerRef;
	}

	void SetListener(IStrategy *listenerRef) {
		listener = listenerRef;
	}

	void CheckToClose(EOrder &order) {
		if (!order.IsPendingToClose()) {
			return;
		}

		datetime currentTime = dtime.Timestamp();
		SOrderRetryState retry = order.GetCloseRetry();

		if (retry.after > 0 && currentTime < retry.after) {
			return;
		}

		if (retry.count >= MAX_RETRY_COUNT_CLOSE) {
			logger.Error(LOG_CODE_ORDER_RETRY_EXHAUSTED, StringFormat(
				"order retry exhausted | symbol=%s order_id=%s retry=%d reason='max close retries reached'",
				symbol,
				order.GetId(),
				retry.count
			));
			retry.Reset();
			order.SetCloseRetry(retry);
			order.SetPendingToClose(false);
			return;
		}

		Close(order);
	}

	void Close(EOrder &order) {
		SMarketStatus marketStatus = GetMarketStatus(symbol);

		if (marketStatus.isClosed) {
			SOrderRetryState retry = order.GetCloseRetry();
			if (retry.retryable) {
				retry.after = dtime.Timestamp() + marketStatus.opensInSeconds;
				order.SetCloseRetry(retry);
				order.SetPendingToClose(true);
				logger.Warning(LOG_CODE_ORDER_RETRY_SCHEDULED, StringFormat(
					"close retry scheduled | symbol=%s order_id=%s reason='market closed' retry_in_s=%d",
					symbol,
					order.GetId(),
					marketStatus.opensInSeconds
				));
				return;
			}

			dropClose(order, LOG_CODE_ORDER_CLOSE_FAILED, "market closed");
			return;
		}

		logger.Info(LOG_CODE_ORDER_CLOSE_QUEUED, StringFormat(
			"order close queued | symbol=%s order_id=%s position_id=%llu",
			symbol,
			order.GetId(),
			order.GetPositionId()
		));

		STradeResult result = trade.Close(order.GetPositionId());

		if (result.severity == TRADE_SEVERITY_SUCCESS) {
			logger.Info(LOG_CODE_ORDER_CLOSE_QUEUED, StringFormat(
				"order close sent | symbol=%s order_id=%s position_id=%llu",
				symbol,
				order.GetId(),
				order.GetPositionId()
			));
			order.SetStatus(ORDER_STATUS_CLOSING);
			order.SetPendingToClose(false);
			SOrderRetryState cleared = order.GetCloseRetry();
			cleared.Reset();
			order.SetCloseRetry(cleared);

			finalizer.Persist(order);

			if (CheckPointer(listener) != POINTER_INVALID) {
				listener.OnOrderUpdated(order);
			}
			return;
		}

		if (result.severity == TRADE_SEVERITY_TRANSIENT) {
			SOrderRetryState retry = order.GetCloseRetry();
			if (!retry.retryable) {
				dropClose(order, GetTradeRetcodeLogCode(result.retcode), ATrade::DescribeRetcode(result.retcode));
				return;
			}

			int deferSeconds = ResolveTransientDeferSeconds(result.retcode, symbol);
			retry.after = dtime.Timestamp() + deferSeconds;
			order.SetCloseRetry(retry);
			order.SetPendingToClose(true);
			logger.Warning(GetTradeRetcodeLogCode(result.retcode), StringFormat(
				"close retry scheduled | symbol=%s order_id=%s reason='%s' retry_in_s=%d",
				symbol,
				order.GetId(),
				ATrade::DescribeRetcode(result.retcode),
				deferSeconds
			));
			return;
		}

		SOrderRetryState retry = order.GetCloseRetry();
		if (!retry.retryable) {
			logger.Error(GetTradeRetcodeLogCode(result.retcode), StringFormat(
				"order close dropped | symbol=%s order_id=%s position_id=%llu error=%d reason='%s'",
				symbol,
				order.GetId(),
				order.GetPositionId(),
				result.retcode,
				ATrade::DescribeRetcode(result.retcode)
			));
			retry.Reset();
			order.SetCloseRetry(retry);
			order.SetPendingToClose(false);
			return;
		}

		retry.count += 1;
		retry.after = dtime.Timestamp() + TRANSIENT_DEFER_DEFAULT_SECONDS;
		order.SetCloseRetry(retry);
		order.SetPendingToClose(true);
		logger.Error(GetTradeRetcodeLogCode(result.retcode), StringFormat(
			"order close failed | symbol=%s order_id=%s position_id=%llu retry=%d error=%d reason='%s'",
			symbol,
			order.GetId(),
			order.GetPositionId(),
			retry.count,
			result.retcode,
			ATrade::DescribeRetcode(result.retcode)
		));
	}

	void HandleCloseResult(
		EOrder &order,
		const SDateTime &time,
		double price,
		double profits,
		double grossProfit,
		double commission,
		double swap,
		ENUM_DEAL_REASON reason
	) {
		bool isCancelled = (profits == 0.0 && price == 0.0);

		order.SetCloseAt(time);
		order.SetClosePrice(price);
		order.SetGrossProfit(grossProfit);
		order.SetCommission(commission);
		order.SetSwap(swap);
		order.SetProfitInDollars(profits);
		order.SetStatus(isCancelled ? ORDER_STATUS_CANCELLED : ORDER_STATUS_CLOSED);
		order.SetCloseReason(reason);
		order.BuildSnapshot();

		if (isCancelled) {
			logger.Info(LOG_CODE_ORDER_CANCELLED, StringFormat(
				"order cancelled | symbol=%s order_id=%s reason='deal cancelled'",
				symbol,
				order.GetId()
			));
		} else {
			string reasonLabel = describeCloseReason(reason);

			if (reasonLabel != "") {
				logger.Success(LOG_CODE_ORDER_CLOSED, StringFormat(
					"order closed | symbol=%s order_id=%s position_id=%llu reason='%s'",
					symbol,
					order.GetId(),
					order.GetPositionId(),
					reasonLabel
				));
			}
		}

		finalizer.Persist(order);
	}

private:
	void dropClose(EOrder &order, ENUM_LOG_CODE logCode, string reason) {
		SOrderRetryState retry = order.GetCloseRetry();
		retry.Reset();
		order.SetCloseRetry(retry);
		order.SetPendingToClose(false);
		logger.Warning(logCode, StringFormat(
			"order close dropped | symbol=%s order_id=%s reason='%s'",
			symbol,
			order.GetId(),
			reason
		));
	}

	string describeCloseReason(ENUM_DEAL_REASON reason) {
		switch (reason) {
		case DEAL_REASON_TP:     return "Take Profit";
		case DEAL_REASON_SL:     return "Stop Loss";
		case DEAL_REASON_EXPERT: return "Expert";
		case DEAL_REASON_CLIENT: return "Client";
		case DEAL_REASON_MOBILE: return "Mobile";
		case DEAL_REASON_WEB:    return "Web";
		default:                 return "";
		}
	}
};

#endif
