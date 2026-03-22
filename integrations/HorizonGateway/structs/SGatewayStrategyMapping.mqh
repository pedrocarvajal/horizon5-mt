#ifndef __S_GATEWAY_STRATEGY_MAPPING_MQH__
#define __S_GATEWAY_STRATEGY_MAPPING_MQH__

struct SGatewayStrategyMapping {
private:
	ulong magicNumber;
	string uuid;

public:
	SGatewayStrategyMapping() {
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
