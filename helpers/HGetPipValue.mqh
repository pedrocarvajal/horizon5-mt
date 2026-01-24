#ifndef __H_GET_PIP_VALUE_MQH__
#define __H_GET_PIP_VALUE_MQH__

double GetPipValue(string symbolName) {
	double pointSize = SymbolInfoDouble(symbolName, SYMBOL_POINT);
	double tickValue = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_VALUE);
	int digits = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
	double pipMultiplier = (digits == 3 || digits == 5) ? 10.0 : 1.0;

	return tickValue * pipMultiplier;
}

#endif
