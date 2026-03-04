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

	long positionId;

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
		positionId = 0;
	}
};

#endif
