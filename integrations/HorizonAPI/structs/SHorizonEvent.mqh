#ifndef __S_HORIZON_EVENT_MQH__
#define __S_HORIZON_EVENT_MQH__

#include "../../../libraries/Json/index.mqh"

struct SHorizonEvent {
	string id;
	string key;
	string payloadRaw;
	int strategyId;

	string symbol;
	string type;
	double volume;
	double price;
	double stopLoss;
	double takeProfit;
	string comment;

	string orderId;
	long positionId;

	string side;
	string status;

	string timeframe;
	string fromDate;
	string toDate;

	SHorizonEvent() {
		id = "";
		key = "";
		payloadRaw = "";
		strategyId = 0;
		symbol = "";
		type = "";
		volume = 0;
		price = 0;
		stopLoss = 0;
		takeProfit = 0;
		comment = "";
		orderId = "";
		positionId = 0;
		side = "";
		status = "";
		timeframe = "";
		fromDate = "";
		toDate = "";
	}

	void ToJson(JSON::Object &json) {
		json.setProperty("id", id);
		json.setProperty("key", key);
		json.setProperty("payload_raw", payloadRaw);
		json.setProperty("strategy_id", strategyId);
		json.setProperty("symbol", symbol);
		json.setProperty("type", type);
		json.setProperty("volume", volume);
		json.setProperty("price", price);
		json.setProperty("stop_loss", stopLoss);
		json.setProperty("take_profit", takeProfit);
		json.setProperty("comment", comment);
		json.setProperty("order_id", orderId);
		json.setProperty("position_id", positionId);
		json.setProperty("side", side);
		json.setProperty("status", status);
		json.setProperty("timeframe", timeframe);
		json.setProperty("from_date", fromDate);
		json.setProperty("to_date", toDate);
	}

	void FromJson(JSON::Object *json) {
		if (json == NULL) {
			return;
		}

		id = json.getString("id");
		key = json.getString("key");
		payloadRaw = json.getString("payload_raw");
		strategyId = (int)json.getNumber("strategy_id");
		symbol = json.getString("symbol");
		type = json.getString("type");
		volume = json.getNumber("volume");
		price = json.getNumber("price");
		stopLoss = json.getNumber("stop_loss");
		takeProfit = json.getNumber("take_profit");
		comment = json.getString("comment");
		orderId = json.getString("order_id");
		positionId = (long)json.getNumber("position_id");
		side = json.getString("side");
		status = json.getString("status");
		timeframe = json.getString("timeframe");
		fromDate = json.getString("from_date");
		toDate = json.getString("to_date");
	}
};

#endif
