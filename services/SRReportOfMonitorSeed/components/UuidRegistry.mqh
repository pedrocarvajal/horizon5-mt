#ifndef __UUID_REGISTRY_MQH__
#define __UUID_REGISTRY_MQH__

class UuidRegistry {
private:
	string assetSymbols[];
	string assetUuids[];

	ulong strategyMagics[];
	string strategyUuids[];

public:
	void RegisterAsset(string symbolName, string assetUuid) {
		int index = ArraySize(assetSymbols);
		ArrayResize(assetSymbols, index + 1);
		ArrayResize(assetUuids, index + 1);
		assetSymbols[index] = symbolName;
		assetUuids[index] = assetUuid;
	}

	void RegisterStrategy(ulong magicNumber, string strategyUuid) {
		int index = ArraySize(strategyMagics);
		ArrayResize(strategyMagics, index + 1);
		ArrayResize(strategyUuids, index + 1);
		strategyMagics[index] = magicNumber;
		strategyUuids[index] = strategyUuid;
	}

	string GetAssetUuid(string symbolName) const {
		for (int i = 0; i < ArraySize(assetSymbols); i++) {
			if (assetSymbols[i] == symbolName) {
				return assetUuids[i];
			}
		}

		return "";
	}

	string GetStrategyUuid(ulong magicNumber) const {
		for (int i = 0; i < ArraySize(strategyMagics); i++) {
			if (strategyMagics[i] == magicNumber) {
				return strategyUuids[i];
			}
		}

		return "";
	}
};

#endif
