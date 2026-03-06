#ifndef __S_STRATEGY_MAPPING_MQH__
#define __S_STRATEGY_MAPPING_MQH__

struct SStrategyMapping {
	ulong magicNumber;
	string uuid;

	SStrategyMapping() {
		magicNumber = 0;
		uuid = "";
	}
};

#endif
