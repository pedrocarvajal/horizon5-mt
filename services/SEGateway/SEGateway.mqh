#ifndef __SE_GATEWAY_MQH__
#define __SE_GATEWAY_MQH__

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

#include "helpers/HBuildNotificationPayload.mqh"

#include "../../constants/CONotificationType.mqh"
#include "../../constants/COSEGateway.mqh"

extern SRImplementationOfHorizonGateway horizonGateway;

void AckWithError(const string eventId, const string message, SELogger &eventLogger) {
	eventLogger.Warning(LOG_CODE_REMOTE_REQUEST_INVALID, StringFormat(
		"event handler failed | event_id=%s reason='%s'",
		eventId,
		message
	));
	JSON::Object ackBody;
	ackBody.setProperty("status", "error");
	ackBody.setProperty("message", message);
	horizonGateway.AckEvent(eventId, ackBody);
}

class SEStrategy;

class SEGateway {
private:
	string symbol;
	SEStrategy *strategies[];
	int strategyCount;
	SELogger logger;
	PendingEntryTracker tracker;
	datetime lastPollTime;

	bool shouldPoll() {
		datetime now = TimeCurrent();

		if ((now - lastPollTime) < SE_GATEWAY_POLL_INTERVAL_SECONDS) {
			return false;
		}

		lastPollTime = now;
		return true;
	}

public:
	SEGateway() {
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

		logger.SetPrefix("Gateway::" + assetSymbol);
	}

	void ProcessEvents() {
		if (!horizonGateway.IsEnabled() || !shouldPoll()) {
			return;
		}

		SGatewayEvent events[];

		int postCount = horizonGateway.ConsumeEvents("post.order", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < postCount; i++) {
			HandlePostOrder(events[i], symbol, strategies, tracker, logger);
		}

		int deleteCount = horizonGateway.ConsumeEvents("delete.order", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < deleteCount; i++) {
			HandleDeleteOrder(events[i], strategies, tracker, logger);
		}

		int putCount = horizonGateway.ConsumeEvents("put.order", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < putCount; i++) {
			HandlePutOrder(events[i], strategies, logger);
		}

		int getCount = horizonGateway.ConsumeEvents("get.orders", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < getCount; i++) {
			HandleGetOrders(events[i], strategies, logger);
		}

		int totalConsumed = postCount + deleteCount + putCount + getCount;

		if (totalConsumed > 0) {
			logger.Info(LOG_CODE_FRAMEWORK_SERVICE_UNAVAILABLE, StringFormat(
				"events consumed | symbol=%s count=%d",
				symbol,
				totalConsumed
			));
		}
	}

	void OnOpenOrder(EOrder &order, const string strategyUuid) {
		publishOrderNotification(NOTIFICATION_TYPE_ORDER_OPENED, order, strategyUuid);

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

		logger.Info(LOG_CODE_ORDER_OPENED, StringFormat(
			"event acked | event_type=post.order event_id=%s symbol=%s position_id=%llu price=%.5f",
			eventId,
			order.GetSymbol(),
			order.GetPositionId(),
			order.GetOpenPrice()
		));
	}

	void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason, const string strategyUuid) {
		publishOrderCloseNotification(order, reason, strategyUuid);

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

		logger.Info(LOG_CODE_ORDER_CLOSED, StringFormat(
			"event acked | event_type=delete.order event_id=%s symbol=%s position_id=%llu price=%.5f",
			eventId,
			order.GetSymbol(),
			order.GetPositionId(),
			order.GetClosePrice()
		));
	}

	void OnCancelOrder(EOrder &order, const string strategyUuid) {
		publishOrderNotification(NOTIFICATION_TYPE_ORDER_CANCELLED, order, strategyUuid);

		int pendingIndex = tracker.FindOpenIndex(order.GetId());

		if (pendingIndex != -1) {
			string eventId = tracker.ConsumeOpen(pendingIndex);
			ackCancelEvent(eventId, "post.order", "rejected", order);
			return;
		}

		int closeIndex = tracker.FindCloseIndex(order.GetId());

		if (closeIndex != -1) {
			string eventId = tracker.ConsumeClose(closeIndex);
			ackCancelEvent(eventId, "delete.order", "cancelled", order);
		}
	}

	void OnModifyOrder(EOrder &order, const string strategyUuid) {
		publishOrderNotification(NOTIFICATION_TYPE_ORDER_MODIFIED, order, strategyUuid);
	}

private:
	void ackCancelEvent(const string eventId, const string eventType, const string statusValue, EOrder &order) {
		JSON::Object ackBody;
		ackBody.setProperty("status", statusValue);
		ackBody.setProperty("ticket", (long)order.GetOrderId());
		horizonGateway.AckEvent(eventId, ackBody);

		logger.Info(LOG_CODE_ORDER_CANCELLED, StringFormat(
			"event acked | event_type=%s event_id=%s symbol=%s order_id=%s reason=%s",
			eventType,
			eventId,
			order.GetSymbol(),
			order.GetId(),
			statusValue
		));
	}

	void publishOrderNotification(const string notificationType, EOrder &order, const string strategyUuid) {
		if (!horizonGateway.IsEnabled()) {
			return;
		}

		JSON::Object *payload = new JSON::Object();

		if (notificationType == NOTIFICATION_TYPE_ORDER_OPENED) {
			BuildOrderOpenedPayload(order, payload);
		} else if (notificationType == NOTIFICATION_TYPE_ORDER_CANCELLED) {
			BuildOrderCancelledPayload(order, payload);
		} else if (notificationType == NOTIFICATION_TYPE_ORDER_MODIFIED) {
			BuildOrderModifiedPayload(order, payload);
		} else {
			delete payload;
			return;
		}

		horizonGateway.PublishNotification(notificationType, strategyUuid, "", symbol, payload);
	}

	void publishOrderCloseNotification(EOrder &order, ENUM_DEAL_REASON reason, const string strategyUuid) {
		if (!horizonGateway.IsEnabled()) {
			return;
		}

		JSON::Object *payload = new JSON::Object();
		BuildOrderClosedPayload(order, reason, payload);
		horizonGateway.PublishNotification(NOTIFICATION_TYPE_ORDER_CLOSED, strategyUuid, "", symbol, payload);
	}
};

#endif
