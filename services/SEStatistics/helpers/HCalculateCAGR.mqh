#ifndef __H_CALCULATE_CAGR_MQH__
#define __H_CALCULATE_CAGR_MQH__

double CalculateCAGR(double initialValue, double finalValue, int months) {
	if (months <= 0)
		return 0.0;

	if (initialValue <= 0 || finalValue <= 0)
		return 0.0;

	double years = months / 12.0;

	if (years <= 0)
		return 0.0;

	double cagr = MathPow(finalValue / initialValue, 1.0 / years) - 1.0;

	return cagr;
}

#endif
