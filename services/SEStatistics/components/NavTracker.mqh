#ifndef __NAV_TRACKER_MQH__
#define __NAV_TRACKER_MQH__

class NavTracker {
private:
	double nav[];
	double navPeak;
	double navYesterday;
	double dailyPerformance;

public:
	NavTracker() {
		ArrayResize(nav, 0);
		navPeak = 0.0;
		navYesterday = 0.0;
		dailyPerformance = 0.0;
	}

	void Initialize(double initialBalance) {
		ArrayResize(nav, 1);
		nav[0] = initialBalance;
		navPeak = initialBalance;
		navYesterday = initialBalance;
		dailyPerformance = 0.0;
	}

	double GetLatest() const {
		int size = ArraySize(nav);
		return size > 0 ? nav[size - 1] : 0.0;
	}

	double GetPreviousDay() const {
		int size = ArraySize(nav);
		return size > 1 ? nav[size - 2] : 0.0;
	}

	double GetPeak() const {
		return navPeak;
	}

	double GetYesterday() const {
		return navYesterday;
	}

	double GetDailyPerformance() const {
		return dailyPerformance;
	}

	void AppendDay(double realNav) {
		ArrayResize(nav, ArraySize(nav) + 1);
		nav[ArraySize(nav) - 1] = realNav;

		if (realNav > navPeak) {
			navPeak = realNav;
		}

		dailyPerformance = realNav - navYesterday;
		navYesterday = realNav;
	}

	void CopyNav(double &target[]) const {
		ArrayResize(target, ArraySize(nav));
		ArrayCopy(target, nav);
	}

	void Restore(double &restoredNav[], double restoredPeak, double restoredYesterday) {
		ArrayResize(nav, ArraySize(restoredNav));
		ArrayCopy(nav, restoredNav);

		navPeak = restoredPeak;
		navYesterday = restoredYesterday;

		if (ArraySize(nav) > 0) {
			dailyPerformance = nav[ArraySize(nav) - 1] - navYesterday;
		} else {
			dailyPerformance = 0.0;
		}
	}
};

#endif
