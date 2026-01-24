#ifndef __H_GET_MARGIN_PER_LOT_MQH__
#define __H_GET_MARGIN_PER_LOT_MQH__

double GetMarginPerLot(string symbolName) {
	double price = SymbolInfoDouble(symbolName, SYMBOL_ASK);
	double marginRequired = 0;

	if (price <= 0)
		return 0.0;

	if (!OrderCalcMargin(ORDER_TYPE_BUY, symbolName, 1.0, price, marginRequired))
		return 0.0;

	return marginRequired;
}

#endif
