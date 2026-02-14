#ifndef __H_CALCULATE_STABILITY_MQH__
#define __H_CALCULATE_STABILITY_MQH__

#include "HCalculateRSquared.mqh"

double CalculateStability(double &performance[], double totalProfit) {
	if (ArraySize(performance) < 3)
		return 0.0;

	double rSquared = CalculateRSquared(performance);

	if (totalProfit < 0)
		return -1.0 * rSquared;

	return rSquared;
}

double CalculateStabilitySQ3(double &performance[], double totalProfit,
			     int totalTrades) {
	if (ArraySize(performance) < 3)
		return 0.0;

	double rSquared = CalculateRSquared(performance);

	if (totalProfit <= 0)
		return 0.0;

	double correlation = MathSqrt(rSquared);
	double stability = correlation * correlation;

	if (totalTrades < 100) {
		double penalty = (double)totalTrades / 100.0;
		stability *= penalty;
	}

	if (stability > 1.0)
		stability = 1.0;

	if (stability < 0.0)
		stability = 0.0;

	return stability;
}

#endif
