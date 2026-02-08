#ifndef __SQX_CROSSED_ABOVE_MQH__
#define __SQX_CROSSED_ABOVE_MQH__

bool CrossedAbove(double previousValue1, double currentValue1,
		  double previousValue2, double currentValue2) {
	bool previouslyBelow = previousValue1 < previousValue2;
	bool currentlyAbove = currentValue1 > currentValue2;

	return previouslyBelow && currentlyAbove;
}

bool CrossedBelow(double previousValue1, double currentValue1,
		  double previousValue2, double currentValue2) {
	bool previouslyAbove = previousValue1 > previousValue2;
	bool currentlyBelow = currentValue1 < currentValue2;

	return previouslyAbove && currentlyBelow;
}

#endif
