#ifndef __S_MONITOR_ASSET_MAPPING_MQH__
#define __S_MONITOR_ASSET_MAPPING_MQH__

struct SAssetMapping {
private:
	string symbol;
	string uuid;

public:
	SAssetMapping() {
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
