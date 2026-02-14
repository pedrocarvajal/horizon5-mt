#ifndef __SE_LOT_SIZE_MQH__
#define __SE_LOT_SIZE_MQH__

#include "../SELogger/SELogger.mqh"

class SELotSize {
private:
	string symbol;

protected:
	SELogger logger;

public:
	SELotSize(string symbolName) {
		logger.SetPrefix("SELotSize");

		symbol = symbolName;
	}

	double CalculateByStopLoss(double nav, double stopLossDistance, double equityAtRisk) {
		double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
		double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

		if (stopLossDistance <= 0) {
			logger.Warning("CalculateByStopLoss: stopLossDistance is required");
			return 0.0;
		}

		if (tickValue <= 0 || tickSize <= 0) {
			logger.Warning(
				"CalculateByStopLoss: Invalid tick value or tick size");
			return 0.0;
		}

		if (equityAtRisk <= 0) {
			logger.Warning("CalculateByStopLoss: equityAtRisk is required");
			return 0.0;
		}

		double dollarValuePerPoint = tickValue / tickSize;
		double riskAmount = equityAtRisk * nav;

		double result = riskAmount / (stopLossDistance * dollarValuePerPoint);

		logger.Info(StringFormat(
			"CalculateByStopLoss: nav=%.2f, SL=%.5f, equityAtRisk=%.2f, dollarPerPt=%.2f, riskAmt=%.2f, lotSize=%.4f",
			nav, stopLossDistance, equityAtRisk, dollarValuePerPoint,
			riskAmount, result));

		return result;
	}
};

#endif
