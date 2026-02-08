#ifndef __SE_LOT_SIZE_MQH__
#define __SE_LOT_SIZE_MQH__

#include "../SELogger/SELogger.mqh"
#include "../../helpers/HGetMarginPerLot.mqh"

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

	double CalculateByCapital(double nav) {
		double marginPerLot = GetMarginPerLot(symbol);

		if (marginPerLot <= 0) {
			logger.warning(
				"CalculateByCapital: Unable to calculate margin per lot");
			return 0.0;
		}

		double result = nav / marginPerLot;
		logger.info(StringFormat(
				    "CalculateByCapital: nav=%.2f, marginPerLot=%.2f, lotSize=%.4f",
				    nav, marginPerLot, result));

		return result;
	}

	double CalculateByVolatility(double nav, double atrValue,
				     double equityAtRisk) {
		double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
		double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

		if (atrValue <= 0) {
			logger.warning("CalculateByVolatility: ATR value is required");
			return 0.0;
		}

		if (tickValue <= 0 || tickSize <= 0) {
			logger.warning(
				"CalculateByVolatility: Invalid tick value or tick size");
			return 0.0;
		}

		if (equityAtRisk <= 0) {
			logger.warning("CalculateByVolatility: equityAtRisk is required");
			return 0.0;
		}

		double dollarValuePerPoint = tickValue / tickSize;
		double dollarVolatility = atrValue * dollarValuePerPoint;
		double riskAmount = equityAtRisk * nav;

		double result = riskAmount / dollarVolatility;

		logger.info(StringFormat(
				    "CalculateByVolatility: nav=%.2f, ATR=%.5f, equityAtRisk=%.2f, dollarVol=%.2f, riskAmt=%.2f, lotSize=%.4f",
				    nav, atrValue, equityAtRisk, dollarVolatility,
				    riskAmount, result));

		return result;
	}
};

#endif
