#ifndef __H_CALCULATE_SHARPE_RATIO_MQH__
#define __H_CALCULATE_SHARPE_RATIO_MQH__

#define TRADING_HOURS_PER_YEAR 6048

double CalculateSharpeRatio(double &perf[]) {
	int n = ArraySize(perf);

	if (n < 3)
		return 0.0;

	double mean = 0.0, var = 0.0;
	int m = 0;

	for (int i = 1; i < n; i++) {
		double d = perf[i] - perf[i - 1];
		mean += d;
		m++;
	}

	if (m < 2)
		return 0.0;

	mean /= (double)m;

	for (int i = 1; i < n; i++) {
		double d = perf[i] - perf[i - 1];
		double e = d - mean;
		var += e * e;
	}

	var /= (double)(m - 1);
	double sd = (var > 0.0 ? MathSqrt(var) : 0.0);

	if (sd <= 1e-12)
		return 0.0;

	double sharpeRatio = mean / sd;
	double annualizationFactor = MathSqrt((double)TRADING_HOURS_PER_YEAR);

	return sharpeRatio * annualizationFactor;
}

#endif
