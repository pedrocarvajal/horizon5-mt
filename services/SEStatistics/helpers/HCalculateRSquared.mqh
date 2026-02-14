#ifndef __H_CALCULATE_R_SQUARED_MQH__
#define __H_CALCULATE_R_SQUARED_MQH__

double CalculateRSquared(double &points[]) {
	if (ArraySize(points) < 3)
		return 0;

	double xValues[];
	double yValues[];

	ArrayResize(xValues, ArraySize(points));
	ArrayResize(yValues, ArraySize(points));

	for (int i = 0; i < ArraySize(points); i++) {
		xValues[i] = i;
		yValues[i] = points[i];
	}

	double n = ArraySize(points);
	double sumX = 0, sumY = 0, sumXy = 0, sumX2 = 0, sumY2 = 0;

	for (int i = 0; i < n; i++) {
		sumX += xValues[i];
		sumY += yValues[i];
		sumXy += xValues[i] * yValues[i];
		sumX2 += xValues[i] * xValues[i];
		sumY2 += yValues[i] * yValues[i];
	}

	double varianceX = n * sumX2 - sumX * sumX;
	double varianceY = n * sumY2 - sumY * sumY;

	if (varianceX <= 0.0000001 || varianceY <= 0.0000001)
		return 0;

	double numerator = n * sumXy - sumX * sumY;
	double denominator = MathSqrt(varianceX * varianceY);

	if (denominator <= 0.0000001)
		return 0;

	double correlation = numerator / denominator;
	return correlation * correlation;
}

#endif
