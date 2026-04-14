#ifndef __PERFORMANCE_TRACKER_MQH__
#define __PERFORMANCE_TRACKER_MQH__

class PerformanceTracker {
private:
	double performance[];
	double returns[];

public:
	PerformanceTracker() {
		ArrayResize(performance, 1);
		performance[0] = 0.0;
		ArrayResize(returns, 0);
	}

	double GetLatest() const {
		int size = ArraySize(performance);
		return size > 0 ? performance[size - 1] : 0.0;
	}

	double GetAtOffset(int offset) const {
		int index = ArraySize(performance) - 1 - offset;
		return (index >= 0) ? performance[index] : 0.0;
	}

	void ApplyPendingProfit(double profit) {
		int last = ArraySize(performance) - 1;
		if (last < 0) {
			return;
		}

		performance[last] += profit;
	}

	void StartNewDay() {
		double prevPerformance = GetLatest();
		ArrayResize(performance, ArraySize(performance) + 1);
		performance[ArraySize(performance) - 1] = prevPerformance;
	}

	void AppendReturn(double dailyReturn) {
		ArrayResize(returns, ArraySize(returns) + 1);
		returns[ArraySize(returns) - 1] = dailyReturn;
	}

	void CopyPerformance(double &target[]) const {
		ArrayResize(target, ArraySize(performance));
		ArrayCopy(target, performance);
	}

	void CopyReturns(double &target[]) const {
		ArrayResize(target, ArraySize(returns));
		ArrayCopy(target, returns);
	}

	void Restore(double &restoredPerformance[], double &restoredReturns[]) {
		ArrayResize(performance, ArraySize(restoredPerformance));
		ArrayCopy(performance, restoredPerformance);

		ArrayResize(returns, ArraySize(restoredReturns));
		ArrayCopy(returns, restoredReturns);
	}
};

#endif
