#ifndef __SQX_GET_INDICATOR_VALUE_MQH__
#define __SQX_GET_INDICATOR_VALUE_MQH__

double GetIndicatorValue(int handle, int buffer, int shift) {
	double value[];
	ArraySetAsSeries(value, true);

	if (CopyBuffer(handle, buffer, shift, 1, value) > 0)
		return value[0];

	return 0.0;
}

bool GetIndicatorValues(int handle, int buffer, int shift, int count,
			double &values[]) {
	ArraySetAsSeries(values, true);

	return CopyBuffer(handle, buffer, shift, count, values) == count;
}

#endif
