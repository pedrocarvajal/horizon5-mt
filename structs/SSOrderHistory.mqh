#ifndef __SS_ORDER_HISTORY_MQH__
#define __SS_ORDER_HISTORY_MQH__

#include "../enums/EOrderStatuses.mqh"

struct SSOrderHistory {
	string orderId;
	string symbol;
	string strategyName;
	string strategyPrefix;
	ulong magicNumber;
	ulong dealId;
	ulong positionId;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON orderCloseReason;

	double takeProfitPrice;
	double stopLossPrice;

	datetime signalAt;
	double signalPrice;

	datetime openTime;
	double openPrice;
	double openLot;

	datetime closeTime;
	double closePrice;

	double profitInDollars;
};

#endif
