#ifndef __SQX_CROSSED_ABOVE_MQH__
#define __SQX_CROSSED_ABOVE_MQH__

bool CrossedAbove(double previousValue1, double currentValue1,
		  double previousValue2, double currentValue2) {
	bool wasPreviouslyBelow = previousValue1 < previousValue2;
	bool isCurrentlyAbove = currentValue1 > currentValue2;

	return wasPreviouslyBelow && isCurrentlyAbove;
}

bool CrossedBelow(double previousValue1, double currentValue1,
		  double previousValue2, double currentValue2) {
	bool wasPreviouslyAbove = previousValue1 > previousValue2;
	bool isCurrentlyBelow = currentValue1 < currentValue2;

	return wasPreviouslyAbove && isCurrentlyBelow;
}

#endif
