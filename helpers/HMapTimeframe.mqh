#ifndef __H_MAP_TIMEFRAME_MQH__
#define __H_MAP_TIMEFRAME_MQH__

ENUM_TIMEFRAMES MapTimeframe(string tf) {
	if (tf == "M1") {
		return PERIOD_M1;
	}
	if (tf == "M5") {
		return PERIOD_M5;
	}
	if (tf == "M15") {
		return PERIOD_M15;
	}
	if (tf == "M30") {
		return PERIOD_M30;
	}
	if (tf == "H1") {
		return PERIOD_H1;
	}
	if (tf == "H4") {
		return PERIOD_H4;
	}
	if (tf == "D1") {
		return PERIOD_D1;
	}
	if (tf == "W1") {
		return PERIOD_W1;
	}
	if (tf == "MN1") {
		return PERIOD_MN1;
	}
	return PERIOD_CURRENT;
}

#endif
