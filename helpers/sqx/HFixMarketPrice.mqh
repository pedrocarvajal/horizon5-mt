#ifndef __SQX_FIX_MARKET_PRICE_MQH__
#define __SQX_FIX_MARKET_PRICE_MQH__

double FixMarketPrice(double price, string symbolName) {
	double tickSize = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_SIZE);

	if (tickSize == 0) {
		return price;
	}

	int digits = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
	return NormalizeDouble(tickSize * MathRound(NormalizeDouble(price, digits) / tickSize), digits);
}

#endif
