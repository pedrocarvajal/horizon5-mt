#ifndef __H_GET_ASSET_RATE_MQH__
#define __H_GET_ASSET_RATE_MQH__

double GetAssetRate(string currency) {
	if (currency == "USD") {
		return 1.0;
	}

	string pair = currency + "USD";
	double rate = SymbolInfoDouble(pair, SYMBOL_BID);

	if (rate > 0) {
		return rate;
	}

	string inversePair = "USD" + currency;
	double inverseRate = SymbolInfoDouble(inversePair, SYMBOL_BID);

	if (inverseRate > 0) {
		return 1.0 / inverseRate;
	}

	return 1.0;
}

#endif
