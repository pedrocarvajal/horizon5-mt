#ifndef __SS_ORDER_HISTORY_MQH__
#define __SS_ORDER_HISTORY_MQH__

#include "../enums/EOrderStatuses.mqh"

struct SSOrderHistory {
	string orderId;
	string strategyName;
	string strategyPrefix;
	string sourceCustomId;
	ulong magicNumber;
	int layer;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON orderCloseReason;

	double mainTakeProfitInPoints;
	double mainStopLossInPoints;
	double mainTakeProfitAtPrice;
	double mainStopLossAtPrice;

	datetime signalAt;
	datetime openTime;
	double openPrice;
	double openLot;

	datetime closeTime;
	double closePrice;

	double profitInDollars;
};

#endif
