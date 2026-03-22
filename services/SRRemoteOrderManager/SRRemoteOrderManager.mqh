#ifndef __SR_REMOTE_ORDER_MANAGER_MQH__
#define __SR_REMOTE_ORDER_MANAGER_MQH__

#include "../SELogger/SELogger.mqh"
#include "../SRImplementationOfHorizonGateway/SRImplementationOfHorizonGateway.mqh"

#include "../../entities/EOrder.mqh"
#include "../../enums/EOrderStatuses.mqh"
#include "../../helpers/HGetOrderStatus.mqh"
#include "../../structs/STradingStatus.mqh"

#include "PendingEntryTracker.mqh"
#include "handlers/HHandlePostOrder.mqh"
#include "handlers/HHandleDeleteOrder.mqh"
#include "handlers/HHandlePutOrder.mqh"
#include "handlers/HHandleGetOrders.mqh"

#define REMOTE_ORDER_POLL_INTERVAL 3
#define REMOTE_ORDER_MAX_EVENTS    10

extern SRImplementationOfHorizonGateway horizonGateway;

void AckWithError(const string eventId, const string message, SELogger &eventLogger) {
	eventLogger.Warning(StringFormat("Event %s failed: %s", eventId, message));
	JSON::Object ackBody;
	ackBody.setProperty("status", "error");
	ackBody.setProperty("message", message);
	horizonGateway.AckEvent(eventId, ackBody);
}

class SEStrategy;

class SRRemoteOrderManager {
private:
	string symbol;
	SEStrategy *strategies[];
	int strategyCount;
	SELogger logger;
	PendingEntryTracker tracker;
	datetime lastPollTime;

	bool shouldPoll() {
		datetime now = TimeCurrent();

		if ((now - lastPollTime) < REMOTE_ORDER_POLL_INTERVAL) {
			return false;
		}

		lastPollTime = now;
		return true;
	}

public:
	SRRemoteOrderManager() {
		symbol = "";
		strategyCount = 0;
		lastPollTime = 0;
	}

	void Initialize(string assetSymbol, SEStrategy *&assetStrategies[]) {
		symbol = assetSymbol;
		strategyCount = ArraySize(assetStrategies);
		ArrayResize(strategies, strategyCount);

		for (int i = 0; i < strategyCount; i++) {
			strategies[i] = assetStrategies[i];
		}

		logger.SetPrefix("RemoteOrderManager::" + assetSymbol);
	}

	void ProcessEvents() {
		if (!horizonGateway.IsEnabled() || !shouldPoll()) {
			return;
		}

		SGatewayEvent events[];

		int postCount = horizonGateway.ConsumeEvents("post.order", symbol, events, REMOTE_ORDER_MAX_EVENTS);

		for (int i = 0; i < postCount; i++) {
			HandlePostOrder(events[i], symbol, strategies, tracker, logger);
		}

		int deleteCount = horizonGateway.ConsumeEvents("delete.order", symbol, events, REMOTE_ORDER_MAX_EVENTS);

		for (int i = 0; i < deleteCount; i++) {
			HandleDeleteOrder(events[i], strategies, tracker, logger);
		}

		int putCount = horizonGateway.ConsumeEvents("put.order", symbol, events, REMOTE_ORDER_MAX_EVENTS);

		for (int i = 0; i < putCount; i++) {
			HandlePutOrder(events[i], strategies, logger);
		}

		int getCount = horizonGateway.ConsumeEvents("get.orders", symbol, events, REMOTE_ORDER_MAX_EVENTS);

		for (int i = 0; i < getCount; i++) {
			HandleGetOrders(events[i], strategies, logger);
		}

		int totalConsumed = postCount + deleteCount + putCount + getCount;

		if (totalConsumed > 0) {
			logger.Info(StringFormat("Consumed %d events for %s", totalConsumed, symbol));
		}
	}

	void OnOpenOrder(EOrder &order) {
		int index = tracker.FindOpenIndex(order.GetId());

		if (index == -1) {
			return;
		}

		string eventId = tracker.ConsumeOpen(index);

		JSON::Object ackBody;
		ackBody.setProperty("status", "filled");
		ackBody.setProperty("ticket", (long)order.GetPositionId());
		ackBody.setProperty("open_price", order.GetOpenPrice());
		horizonGateway.AckEvent(eventId, ackBody);

		logger.Info(StringFormat(
			"post.order acked | event %s | ticket %llu @ %.5f",
			eventId, order.GetPositionId(), order.GetOpenPrice()
		));
	}

	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		int index = tracker.FindCloseIndex(order.GetId());

		if (index == -1) {
			return;
		}

		string eventId = tracker.ConsumeClose(index);

		JSON::Object ackBody;
		ackBody.setProperty("status", "closed");
		ackBody.setProperty("ticket", (long)order.GetPositionId());
		ackBody.setProperty("close_price", order.GetClosePrice());
		horizonGateway.AckEvent(eventId, ackBody);

		logger.Info(StringFormat(
			"delete.order acked | event %s | position %llu closed @ %.5f",
			eventId, order.GetPositionId(), order.GetClosePrice()
		));
	}

	void OnCancelOrder(EOrder &order) {
		int closeIndex = tracker.FindCloseIndex(order.GetId());

		if (closeIndex != -1) {
			string eventId = tracker.ConsumeClose(closeIndex);

			JSON::Object ackBody;
			ackBody.setProperty("status", "cancelled");
			ackBody.setProperty("ticket", (long)order.GetOrderId());
			horizonGateway.AckEvent(eventId, ackBody);

			logger.Info(StringFormat(
				"delete.order acked | order %s cancelled",
				order.GetId()
			));
		}
	}
};

#endif
