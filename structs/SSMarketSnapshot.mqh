#ifndef __SS_MARKET_SNAPSHOT_MQH__
#define __SS_MARKET_SNAPSHOT_MQH__

struct SSMarketSnapshot {
	datetime timestamp;
	double bid;
	double ask;
	double spread;
	double rolling_performance;
	double rolling_drawdown;
	double rolling_volatility;
};

#endif
