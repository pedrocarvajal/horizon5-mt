#ifndef __S_GATEWAY_ASSET_MAPPING_MQH__
#define __S_GATEWAY_ASSET_MAPPING_MQH__

struct SGatewayAssetMapping {
private:
	string symbol;
	string uuid;

public:
	SGatewayAssetMapping() {
		symbol = "";
		uuid = "";
	}

	string GetSymbol() {
		return symbol;
	}

	void SetSymbol(string value) {
		symbol = value;
	}

	string GetUuid() {
		return uuid;
	}

	void SetUuid(string value) {
		uuid = value;
	}
};

#endif
