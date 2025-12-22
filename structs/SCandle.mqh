#ifndef __SCANDLE_MQH__
#define __SCANDLE_MQH__

struct SCandle {
	datetime open_timestamp;
	double open_price;
	double high_price;
	double low_price;
	double close_price;
	double volume;
	int trades;
};

#endif
