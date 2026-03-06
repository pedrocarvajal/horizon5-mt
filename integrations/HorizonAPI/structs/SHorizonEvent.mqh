#ifndef __S_HORIZON_EVENT_MQH__
#define __S_HORIZON_EVENT_MQH__

struct SHorizonEvent {
	string id;
	string key;
	string payloadRaw;

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
};

#endif
