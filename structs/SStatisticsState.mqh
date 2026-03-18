#ifndef __S_STATISTICS_STATE_MQH__
#define __S_STATISTICS_STATE_MQH__

#include "SSOrderHistory.mqh"

struct SStatisticsState {
	datetime startTime;
	double navPeak;
	double navYesterday;
	double drawdownMaxInDollars;
	double drawdownMaxInPercentage;
	double nav[];
	double performance[];
	double returns[];
	SSOrderHistory ordersHistory[];
};

#endif
