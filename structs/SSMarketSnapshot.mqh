#ifndef __SS_MARKET_SNAPSHOT_MQH__
#define __SS_MARKET_SNAPSHOT_MQH__

struct SSMarketSnapshot {
	datetime timestamp;
	double bid;
	double ask;
	double spread;
	double performance;
	double drawdown;
	double volatility;
	double dailyPerformance;
};

#endif
