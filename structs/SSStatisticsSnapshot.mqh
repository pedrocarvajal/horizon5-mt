#ifndef __SS_STATISTICS_SNAPSHOT_MQH__
#define __SS_STATISTICS_SNAPSHOT_MQH__

struct SSStatisticsSnapshot {
	datetime timestamp;
	string id;

	double nav[];
	double performance[];
	double navPeak;
	double drawdownMaxInDollars;
	double drawdownMaxInPercentage;
	int winningOrders;
	double winningOrdersPerformance;
	int losingOrders;
	double losingOrdersPerformance;
	double maxLoss;

	double rSquared;
	double sharpeRatio;
	double riskRewardRatio;
	double winRate;
	double recoveryFactor;
	double cagr;

	double quality;
	string qualityReason;

	double maxExposureInLots;
	double maxExposureInPercentage;

	SSOrderHistory orders[];
};

#endif
