#ifndef __SQX_NORMALIZE_LOT_SIZE_MQH__
#define __SQX_NORMALIZE_LOT_SIZE_MQH__

double NormalizeLotSize(double lots, string symbolName) {
	double lotStep = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_STEP);
	double minLot = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN);
	double maxLot = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);
	double normalized = MathFloor(lots / lotStep) * lotStep;

	if (normalized < minLot) {
		return 0;
	}

	if (normalized > maxLot) {
		normalized = maxLot;
	}

	return NormalizeDouble(normalized, 2);
}

#endif
