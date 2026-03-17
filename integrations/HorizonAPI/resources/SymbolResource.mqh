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
		JSON::Object body;
		body.setProperty("name", symbolName);
		body.setProperty("contract_size", ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_TRADE_CONTRACT_SIZE), 13, 2));
		body.setProperty("currency_profit", SymbolInfoString(symbolName, SYMBOL_CURRENCY_PROFIT));
		body.setProperty("digits", (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS));

		context.Post("api/v1/symbol/", body);
	}
};

#endif
