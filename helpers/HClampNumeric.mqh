#ifndef __H_CLAMP_NUMERIC_MQH__
#define __H_CLAMP_NUMERIC_MQH__

double ClampNumeric(double value, int integerDigits, int decimalDigits) {
	double maxValue = MathPow(10, integerDigits) - MathPow(10, -decimalDigits);
	double clamped = MathMin(MathMax(value, -maxValue), maxValue);
	return NormalizeDouble(clamped, decimalDigits);
}

#endif
