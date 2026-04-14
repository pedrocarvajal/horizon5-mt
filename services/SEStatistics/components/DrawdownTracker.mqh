#ifndef __DRAWDOWN_TRACKER_MQH__
#define __DRAWDOWN_TRACKER_MQH__

class DrawdownTracker {
private:
	double maxInDollars;
	double maxInPercentage;

public:
	DrawdownTracker() {
		maxInDollars = 0.0;
		maxInPercentage = 0.0;
	}

	double GetMaxInDollars() const {
		return maxInDollars;
	}

	double GetMaxInPercentage() const {
		return maxInPercentage;
	}

	void Update(double navPeak, double realNav) {
		double drawdownInDollars = navPeak - realNav;

		if (drawdownInDollars > maxInDollars) {
			maxInDollars = drawdownInDollars;
			maxInPercentage = (navPeak > 0) ? maxInDollars / navPeak : 0.0;
		}
	}

	void Restore(double restoredMaxInDollars, double restoredMaxInPercentage) {
		maxInDollars = restoredMaxInDollars;
		maxInPercentage = restoredMaxInPercentage;
	}
};

#endif
