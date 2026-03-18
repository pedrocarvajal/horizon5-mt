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

	double quality;
	string qualityReason;

	double dailyPerformance;

	SSOrderHistory orders[];
};

#endif
