#ifndef __SYMBOL_RESOURCE_MQH__
#define __SYMBOL_RESOURCE_MQH__

#include "../../../helpers/HClampNumeric.mqh"

#include "../HorizonAPIContext.mqh"

class SymbolResource {
private:
	HorizonAPIContext * context;

public:
	SymbolResource(HorizonAPIContext * ctx) {
		context = ctx;
	}

	void Upsert(string symbolName) {
		string currencyProfit = SymbolInfoString(symbolName, SYMBOL_CURRENCY_PROFIT);
		double usdRate = getUsdRate(currencyProfit);

		JSON::Object body;
		body.setProperty("name", symbolName);
		body.setProperty("contract_size", ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_TRADE_CONTRACT_SIZE), 13, 2));
		body.setProperty("currency_profit", currencyProfit);
		body.setProperty("usd_rate", ClampNumeric(usdRate, 7, 8));
		body.setProperty("digits", (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS));

		context.Post("api/v1/symbol/", body);
	}

private:
	double getUsdRate(string currency) {
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
};

#endif
