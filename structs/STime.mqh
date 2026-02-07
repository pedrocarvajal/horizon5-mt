#ifndef __STIME_MQH__
#define __STIME_MQH__

struct STime {
	int hour;
	int minute;

	STime() {
		hour = 0;
		minute = 0;
	}
};

#endif
