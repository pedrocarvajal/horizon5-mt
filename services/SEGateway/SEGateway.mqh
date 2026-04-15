#ifndef __SE_GATEWAY_MQH__
#define __SE_GATEWAY_MQH__

#include "../../constants/CONotificationType.mqh"
#include "../../constants/COSEGateway.mqh"

#include "../SELogger/SELogger.mqh"

#include "../SRImplementationOfHorizonGateway/SRImplementationOfHorizonGateway.mqh"

#include "../../entities/EOrder.mqh"

#include "../../enums/EOrderStatuses.mqh"

#include "../../helpers/HGetOrderSide.mqh"
#include "../../helpers/HGetOrderStatus.mqh"

#include "../../structs/STradingStatus.mqh"

#include "../../integrations/HorizonGateway/structs/SGatewayEvent.mqh"

#include "components/PendingEntryTracker.mqh"

#include "helpers/HBuildOrderPayloadCommon.mqh"
#include "helpers/HBuildOrderOpenedPayload.mqh"
#include "helpers/HBuildOrderClosedPayload.mqh"
#include "helpers/HBuildOrderCancelledPayload.mqh"
#include "helpers/HBuildOrderModifiedPayload.mqh"
#include "helpers/HParseOrderType.mqh"
#include "helpers/HSanitizePrice.mqh"

extern SRImplementationOfHorizonGateway horizonGateway;
extern STradingStatus tradingStatus;

class SEStrategy;

class SEGateway {
private:
	string symbol;
	SEStrategy *strategies[];
	int strategyCount;
	SELogger logger;
	PendingEntryTracker tracker;
	datetime lastPollTime;

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

		logger.Info(
			LOG_CODE_ORDER_CLOSED,
			StringFormat(
				"event acked | event_type=delete.order event_id=%s symbol=%s position_id=%llu price=%.5f",
				eventId,
				order.GetSymbol(),
				order.GetPositionId(),
				order.GetClosePrice()
		));
	}

	void OnModifyOrder(EOrder &order, const string strategyUuid) {
		publishOrderNotification(NOTIFICATION_TYPE_ORDER_MODIFIED, order, strategyUuid);
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

		logger.Info(
			LOG_CODE_ORDER_OPENED,
			StringFormat(
				"event acked | event_type=post.order event_id=%s symbol=%s position_id=%llu price=%.5f",
				eventId,
				order.GetSymbol(),
				order.GetPositionId(),
				order.GetOpenPrice()
		));
	}

	void ProcessEvents() {
		if (!horizonGateway.IsEnabled() || !shouldPoll()) {
			return;
		}

		SGatewayEvent events[];

		int postCount = horizonGateway.ConsumeEvents("post.order", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < postCount; i++) {
			handlePostOrder(events[i]);
		}

		int deleteCount = horizonGateway.ConsumeEvents("delete.order", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < deleteCount; i++) {
			handleDeleteOrder(events[i]);
		}

		int putCount = horizonGateway.ConsumeEvents("put.order", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < putCount; i++) {
			handlePutOrder(events[i]);
		}

		int getCount = horizonGateway.ConsumeEvents("get.orders", symbol, events, SE_GATEWAY_MAX_EVENTS);

		for (int i = 0; i < getCount; i++) {
			handleGetOrders(events[i]);
		}

		int totalConsumed = postCount + deleteCount + putCount + getCount;

		if (totalConsumed > 0) {
			logger.Info(
				LOG_CODE_REMOTE_HTTP_OK,
				StringFormat(
					"events consumed | symbol=%s count=%d",
					symbol,
					totalConsumed
			));
		}
	}

private:
	void ackWithError(const string eventId, const string message);

	void handlePostOrder(SGatewayEvent &event);
	void handleDeleteOrder(SGatewayEvent &event);
	void handlePutOrder(SGatewayEvent &event);
	void handleGetOrders(SGatewayEvent &event);

	JSON::Object *serializeActiveOrder(EOrder *order, SEOrderBook *orderBook);
	bool matchesOrderFilters(EOrder *order, SGatewayEvent &event);
	bool isDuplicateId(const string &addedIds[], const string orderId);

	void ackCancelEvent(const string eventId, const string eventType, const string statusValue, EOrder &order) {
		JSON::Object ackBody;
		ackBody.setProperty("status", statusValue);
		ackBody.setProperty("ticket", (long)order.GetOrderId());
		horizonGateway.AckEvent(eventId, ackBody);

		logger.Info(
			LOG_CODE_ORDER_CANCELLED,
			StringFormat(
				"event acked | event_type=%s event_id=%s symbol=%s order_id=%s reason=%s",
				eventType,
				eventId,
				order.GetSymbol(),
				order.GetId(),
				statusValue
		));
	}

	void publishOrderCloseNotification(EOrder &order, ENUM_DEAL_REASON reason, const string strategyUuid) {
		if (!horizonGateway.IsEnabled()) {
			return;
		}

		JSON::Object *payload = new JSON::Object();
		BuildOrderClosedPayload(order, reason, payload);
		horizonGateway.PublishNotification(NOTIFICATION_TYPE_ORDER_CLOSED, strategyUuid, "", symbol, payload);
	}

	void publishOrderNotification(const string notificationType, EOrder &order, const string strategyUuid) {
		if (!horizonGateway.IsEnabled()) {
			return;
		}

		bool isSupported = notificationType == NOTIFICATION_TYPE_ORDER_OPENED
				   || notificationType == NOTIFICATION_TYPE_ORDER_CANCELLED
				   || notificationType == NOTIFICATION_TYPE_ORDER_MODIFIED;

		if (!isSupported) {
			return;
		}

		JSON::Object *payload = new JSON::Object();

		if (notificationType == NOTIFICATION_TYPE_ORDER_OPENED) {
			BuildOrderOpenedPayload(order, payload);
		} else if (notificationType == NOTIFICATION_TYPE_ORDER_CANCELLED) {
			BuildOrderCancelledPayload(order, payload);
		} else {
			BuildOrderModifiedPayload(order, payload);
		}

		horizonGateway.PublishNotification(notificationType, strategyUuid, "", symbol, payload);
	}

	bool shouldPoll() {
		datetime now = TimeCurrent();

		if ((now - lastPollTime) < SE_GATEWAY_POLL_INTERVAL_SECONDS) {
			return false;
		}

		lastPollTime = now;
		return true;
	}
};

#include "helpers/HAckWithError.mqh"

#include "handlers/HHandlePostOrder.mqh"
#include "handlers/HHandleDeleteOrder.mqh"
#include "handlers/HHandlePutOrder.mqh"
#include "handlers/HSerializeActiveOrder.mqh"
#include "handlers/HMatchesOrderFilters.mqh"
#include "handlers/HIsDuplicateId.mqh"
#include "handlers/HHandleGetOrders.mqh"

#endif
