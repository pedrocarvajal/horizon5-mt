#ifndef __EVENT_RESOURCE_MQH__
#define __EVENT_RESOURCE_MQH__

#include "../structs/SHorizonEvent.mqh"

#include "../HorizonAPIContext.mqh"

#define EVENT_KEY_POST_ORDER   "post.order"
#define EVENT_KEY_DELETE_ORDER  "delete.order"
#define EVENT_KEY_PUT_ORDER    "put.order"
#define EVENT_KEY_GET_ORDERS   "get.orders"
#define EVENT_KEY_GET_TICKER   "get.ticker"
#define EVENT_KEY_GET_KLINES   "get.klines"

class EventResource {
private:
	HorizonAPIContext * context;
	SELogger logger;

	void parsePostOrderPayload(JSON::Object *payload, SHorizonEvent &event) {
		event.symbol = payload.getString("symbol");
		event.type = payload.getString("type");
		event.volume = payload.getNumber("volume");
		event.price = payload.getNumber("price");
		event.stopLoss = payload.getNumber("stop_loss");
		event.takeProfit = payload.getNumber("take_profit");
		event.comment = payload.getString("comment");
	}

	void parseDeleteOrderPayload(JSON::Object *payload, SHorizonEvent &event) {
		event.orderId = payload.getString("id");
	}

	void parsePutOrderPayload(JSON::Object *payload, SHorizonEvent &event) {
		event.orderId = payload.getString("id");
		event.stopLoss = payload.getNumber("stop_loss");
		event.takeProfit = payload.getNumber("take_profit");
	}

	void parseGetOrdersPayload(JSON::Object *payload, SHorizonEvent &event) {
		event.symbol = payload.getString("symbol");
		event.side = payload.getString("side");
		event.status = payload.getString("status");
	}

	void parseGetTickerPayload(JSON::Object *payload, SHorizonEvent &event) {
		event.symbol = payload.getString("symbols");
	}

	void parseGetKlinesPayload(JSON::Object *payload, SHorizonEvent &event) {
		event.symbol = payload.getString("symbol");
		event.timeframe = payload.getString("timeframe");
		event.fromDate = payload.getString("from_date");
		event.toDate = payload.getString("to_date");
	}

	void parseEventPayload(const string key, JSON::Object *payload, SHorizonEvent &event) {
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

	void parseEvent(JSON::Object *eventObject, SHorizonEvent &event) {
		event.id = eventObject.getString("id");
		event.key = eventObject.getString("key");
		event.strategyId = (int)eventObject.getNumber("strategy");

		JSON::Object *payload = eventObject.getObject("payload");

		if (payload == NULL) {
			return;
		}

		event.payloadRaw = payload.toString();
		parseEventPayload(event.key, payload, event);
	}

	int fillEventsFromArray(JSON::Array *dataArray, SHorizonEvent &events[]) {
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
	EventResource(HorizonAPIContext * ctx) {
		context = ctx;
		logger.SetPrefix("EventResource");
	}

	int Consume(const string keys, const string symbolFilter, SHorizonEvent &events[], int limit = 10, int strategyFilter = 0) {
		string path = StringFormat(
			"api/v1/account/%d/events/consume/?key=%s&limit=%d",
			context.GetAccountId(), keys, limit
		);

		if (symbolFilter != "") {
			path += "&symbol=" + symbolFilter;
		}

		if (strategyFilter > 0) {
			path += "&strategy=" + IntegerToString(strategyFilter);
		}

		JSON::Object emptyBody;
		SRequestResponse response = context.PostWithResponse(path, emptyBody, 0);

		if (response.status == 401) {
			logger.Error("Unauthorized (401) on Consume, check credentials. Disabling HorizonAPI.");
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
			"api/v1/account/%d/event/%s/ack/",
			context.GetAccountId(), eventId
		);

		JSON::Object wrapper;
		wrapper.setProperty("response", &responseBody);

		SRequestResponse response = context.Patch(path, wrapper);

		if (response.status == 401) {
			logger.Error("Unauthorized (401) on Ack, check credentials. Disabling HorizonAPI.");
			context.Disable();
			return false;
		}

		return response.status == 200;
	}
};

#endif
