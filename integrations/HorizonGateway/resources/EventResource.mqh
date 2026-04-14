#ifndef __GATEWAY_EVENT_RESOURCE_MQH__
#define __GATEWAY_EVENT_RESOURCE_MQH__

#include "../structs/SGatewayEvent.mqh"

#include "../HorizonGatewayContext.mqh"

#include "../../../services/SELogger/SELogger.mqh"

#include "../../../constants/COEventKey.mqh"

class EventResource {
private:
	HorizonGatewayContext * context;
	SELogger logger;

	void parsePostOrderPayload(JSON::Object *payload, SGatewayEvent &event) {
		event.symbol = payload.getString("symbol");
		event.type = payload.getString("type");
		event.volume = payload.getNumber("volume");
		event.price = payload.getNumber("price");
		event.stopLoss = payload.getNumber("stop_loss");
		event.takeProfit = payload.getNumber("take_profit");
		event.comment = payload.getString("comment");
	}

	void parseDeleteOrderPayload(JSON::Object *payload, SGatewayEvent &event) {
		event.orderId = payload.getString("id");
		event.symbol = payload.getString("symbol");
	}

	void parsePutOrderPayload(JSON::Object *payload, SGatewayEvent &event) {
		event.orderId = payload.getString("id");
		event.symbol = payload.getString("symbol");
		event.stopLoss = payload.getNumber("stop_loss");
		event.takeProfit = payload.getNumber("take_profit");
	}

	void parseGetOrdersPayload(JSON::Object *payload, SGatewayEvent &event) {
		event.symbol = payload.getString("symbol");
		event.side = payload.getString("side");
		event.status = payload.getString("status");
	}

	void parseGetTickerPayload(JSON::Object *payload, SGatewayEvent &event) {
		event.symbol = payload.getString("symbols");
	}

	void parseGetKlinesPayload(JSON::Object *payload, SGatewayEvent &event) {
		event.symbol = payload.getString("symbol");
		event.timeframe = payload.getString("timeframe");
		event.fromDate = payload.getString("from_date");
		event.toDate = payload.getString("to_date");
	}

	void parseEventPayload(const string key, JSON::Object *payload, SGatewayEvent &event) {
		if (key == EVENT_KEY_POST_ORDER) {
			parsePostOrderPayload(payload, event);
		} else if (key == EVENT_KEY_DELETE_ORDER) {
			parseDeleteOrderPayload(payload, event);
		} else if (key == EVENT_KEY_PUT_ORDER) {
			parsePutOrderPayload(payload, event);
		} else if (key == EVENT_KEY_GET_ORDERS) {
			parseGetOrdersPayload(payload, event);
		} else if (key == EVENT_KEY_GET_TICKER) {
			parseGetTickerPayload(payload, event);
		} else if (key == EVENT_KEY_GET_KLINES) {
			parseGetKlinesPayload(payload, event);
		}
	}

	void parseEvent(JSON::Object *eventObject, SGatewayEvent &event) {
		event.id = eventObject.getString("id");
		event.key = eventObject.getString("key");
		event.strategyId = eventObject.getString("strategy_id");

		JSON::Object *payload = eventObject.getObject("payload");

		if (payload == NULL) {
			return;
		}

		event.payloadRaw = payload.toString();
		parseEventPayload(event.key, payload, event);
	}

	int fillEventsFromArray(JSON::Array *dataArray, SGatewayEvent &events[]) {
		int eventCount = dataArray.getLength();

		if (eventCount == 0) {
			return 0;
		}

		ArrayResize(events, eventCount);
		int filledCount = 0;

		for (int i = 0; i < eventCount; i++) {
			JSON::Object *eventObject = dataArray.getObject(i);

			if (eventObject == NULL) {
				continue;
			}

			parseEvent(eventObject, events[filledCount]);
			filledCount++;
		}

		if (filledCount < eventCount) {
			ArrayResize(events, filledCount);
		}

		return filledCount;
	}

public:
	EventResource(HorizonGatewayContext * ctx) {
		context = ctx;
		logger.SetPrefix("Gateway::Event");
	}

	int Consume(const string keys, const string symbolFilter, SGatewayEvent &events[], int limit = 10, const string strategyFilter = "") {
		string path = StringFormat(
			"api/v1/account/%s/events/consume?key=%s&limit=%d",
			context.GetAccountUuid(), keys, limit
		);

		if (symbolFilter != "") {
			path += "&asset_id=" + symbolFilter;
		}

		if (strategyFilter != "") {
			path += "&strategy_id=" + strategyFilter;
		}

		JSON::Object emptyBody;
		SRequestResponse response = context.Post(path, emptyBody);

		if (response.status == 401) {
			logger.Error(LOG_CODE_REMOTE_AUTH_FAILED, "remote auth failed | endpoint=consume reason='unauthorized 401' action='disabling gateway'");
			context.Disable();
			return 0;
		}

		if (response.status != 200 || response.body == "") {
			return 0;
		}

		JSON::Object root(response.body);

		if (!root.isArray("data")) {
			return 0;
		}

		JSON::Array *dataArray = root.getArray("data");
		return fillEventsFromArray(dataArray, events);
	}

	bool Ack(const string eventId, JSON::Object &responseBody) {
		string path = StringFormat(
			"api/v1/account/%s/event/%s/ack",
			context.GetAccountUuid(), eventId
		);

		JSON::Object wrapper;
		wrapper.setProperty("response", &responseBody);

		SRequestResponse response = context.Patch(path, wrapper);

		if (response.status == 401) {
			logger.Error(LOG_CODE_REMOTE_AUTH_FAILED, "remote auth failed | endpoint=ack reason='unauthorized 401' action='disabling gateway'");
			context.Disable();
			return false;
		}

		return response.status == 200;
	}
};

#endif
