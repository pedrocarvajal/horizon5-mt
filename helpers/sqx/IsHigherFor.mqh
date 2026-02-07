#ifndef __SQX_IS_HIGHER_FOR_MQH__
#define __SQX_IS_HIGHER_FOR_MQH__

bool IsHigherFor(double &values1[], double &values2[], int bars) {
	if (ArraySize(values1) < bars || ArraySize(values2) < bars)
		return false;

	for (int i = 0; i < bars; i++)
		if (values1[i] <= values2[i])
			return false;

	return true;
}

bool IsLowerFor(double &values1[], double &values2[], int bars) {
	if (ArraySize(values1) < bars || ArraySize(values2) < bars)
		return false;

	for (int i = 0; i < bars; i++)
		if (values1[i] >= values2[i])
			return false;

	return true;
}

#endif
