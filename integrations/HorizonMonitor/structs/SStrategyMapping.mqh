#ifndef __S_MONITOR_STRATEGY_MAPPING_MQH__
#define __S_MONITOR_STRATEGY_MAPPING_MQH__

struct SStrategyMapping {
private:
	ulong magicNumber;
	string uuid;

public:
	SStrategyMapping() {
		magicNumber = 0;
		uuid = "";
	}

	ulong GetMagicNumber() {
		return magicNumber;
	}

	void SetMagicNumber(ulong value) {
		magicNumber = value;
	}

	string GetUuid() {
		return uuid;
	}

	void SetUuid(string value) {
		uuid = value;
	}
};

#endif
