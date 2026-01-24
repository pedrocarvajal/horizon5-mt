#ifndef __H_GET_PIP_SIZE_MQH__
#define __H_GET_PIP_SIZE_MQH__

double GetPipSize(string symbolName) {
	double pointSize = SymbolInfoDouble(symbolName, SYMBOL_POINT);
	int digits = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);

	return (digits == 3 || digits == 5) ? pointSize * 10 : pointSize;
}

#endif
