#ifndef __SE_ASSET_MQH__
#define __SE_ASSET_MQH__

#include "../entities/EOrder.mqh"
#include "../helpers/HStringToNumber.mqh"
#include "../interfaces/IAsset.mqh"
#include "../services/SELogger/SELogger.mqh"
#include "../indicators/INRollingReturn.mqh"
#include "../indicators/INDrawdownFromPeak.mqh"
#include "../indicators/INVolatility.mqh"
#include "../indicators/INMaxDrawdownInWindow.mqh"
#include "../helpers/HGetLogsPath.mqh"
#include "../services/SEReportOfLogs/SEReportOfLogs.mqh"
#include "../services/SEReportOfMarketSnapshots/SEReportOfMarketSnapshots.mqh"
#include "../services/SEStrategyAllocator/SEStrategyAllocator.mqh"
#include "../strategies/Strategy.mqh"

extern SEDateTime dtime;

class SEAsset:
public IAsset {
private:
	SELogger logger;
	SEReportOfMarketSnapshots *marketSnapshotsReporter;
	SEStrategyAllocator *allocator;

	string name;
	double weight;
	bool isEnabled;
	double balance;

	SEStrategy *strategies[];

	void collectDailyPerformances(double &dailyPerformances[]) {
		int strategyCount = ArraySize(strategies);
		ArrayResize(dailyPerformances, strategyCount);

		for (int i = 0; i < strategyCount; i++) {
			dailyPerformances[i] = strategies[i].GetStatistics().GetDailyPerformancePercent();
		}
	}

	void redistributeBalances(string &activeStrategyPrefixes[]) {
		int activeCount = ArraySize(activeStrategyPrefixes);
		int strategyCount = ArraySize(strategies);
		double balancePerActive = (activeCount > 0) ? balance / activeCount : 0;

		for (int i = 0; i < strategyCount; i++) {
			bool shouldBeActive = false;

			for (int j = 0; j < activeCount; j++) {
				if (strategies[i].GetPrefix() == activeStrategyPrefixes[j]) {
					shouldBeActive = true;
					break;
				}
			}

			double previousBalance = strategies[i].GetBalance();
			double newBalance = shouldBeActive ? balancePerActive : 0;

			if (previousBalance != newBalance) {
				strategies[i].SetBalance(newBalance);

				if (newBalance > 0) {
					logger.Info(StringFormat(
						"(SEStrategyAllocator) %s allocated: %.2f (was %.2f)",
						strategies[i].GetPrefix(),
						newBalance,
						previousBalance
					));
				} else {
					logger.Info(StringFormat(
						"(SEStrategyAllocator) %s deallocated (was %.2f)",
						strategies[i].GetPrefix(),
						previousBalance
					));
				}
			}
		}
	}

	void runAllocator() {
		if (CheckPointer(allocator) == POINTER_INVALID)
			return;

		double dailyPerformances[];
		collectDailyPerformances(dailyPerformances);

		double rollingReturn = RollingReturn(symbol, PERIOD_D1, AllocatorRollingWindow, 0);
		double rollingVolatility = Volatility(symbol, PERIOD_D1, AllocatorRollingWindow, 0);
		double rollingDrawdown = MaxDrawdownInWindow(symbol, PERIOD_D1, AllocatorRollingWindow, 0);

		allocator.OnStartDay(
			rollingReturn,
			rollingVolatility,
			rollingDrawdown,
			dailyPerformances
		);

		if (!allocator.IsWarmupComplete())
			return;

		string activeStrategyPrefixes[];
		allocator.GetActiveStrategies(activeStrategyPrefixes);
		redistributeBalances(activeStrategyPrefixes);
	}

	SSMarketSnapshot BuildMarketSnapshot() {
		SSMarketSnapshot snapshot;
		snapshot.timestamp = dtime.Timestamp();
		snapshot.bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		snapshot.ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		snapshot.spread = snapshot.ask - snapshot.bid;
		snapshot.rollingPerformance = RollingReturn(symbol, PERIOD_D1, 90, 0);
		snapshot.rollingDrawdown = DrawdownFromPeak(symbol, PERIOD_D1, 90, 0);
		snapshot.rollingVolatility = Volatility(symbol, PERIOD_D1, 90, 0);
		return snapshot;
	}

protected:
	string symbol;

public:
	SEAsset() {
		logger.SetPrefix("SEAsset");
		weight = 0;
		isEnabled = false;
	}

	~SEAsset() {
		if (CheckPointer(marketSnapshotsReporter) == POINTER_DYNAMIC)
			delete marketSnapshotsReporter;

		if (CheckPointer(allocator) == POINTER_DYNAMIC)
			delete allocator;

		for (int i = 0; i < ArraySize(strategies); i++) {
			if (CheckPointer(strategies[i]) != POINTER_DYNAMIC)
				continue;

			delete strategies[i];
		}
	}

	virtual int OnInit() {
		int strategyCount = ArraySize(strategies);
		isEnabled = strategyCount > 0;

		if (!isEnabled) {
			logger.Info(StringFormat(
				"Asset skipped (no strategies enabled): %s",
				name
			));

			return INIT_SUCCEEDED;
		}

		double weightPerStrategy = weight / strategyCount;
		double balancePerStrategy = balance / strategyCount;

		for (int i = 0; i < strategyCount; i++) {
			strategies[i].SetWeight(weightPerStrategy);
			strategies[i].SetBalance(balancePerStrategy);

			int result = strategies[i].OnInit();

			if (result != INIT_SUCCEEDED) {
				logger.Error(StringFormat(
					"Strategy initialization failed: %s",
					strategies[i].GetName()));
				return INIT_FAILED;
			}
		}

		if (EnableMarketHistoryReport) {
			string marketReportName = StringFormat("%s_MARKET_Snapshots", symbol);
			marketSnapshotsReporter = new SEReportOfMarketSnapshots(symbol, marketReportName);
		}

		if (EnableStrategyAllocator) {
			allocator = new SEStrategyAllocator(AllocatorMode, AllocatorRollingWindow, AllocatorNormalizationWindow, AllocatorKNeighbors, AllocatorMaxActiveStrategies, AllocatorScoreThreshold, AllocatorForwardWindow);

			for (int i = 0; i < strategyCount; i++) {
				allocator.RegisterStrategy(strategies[i].GetPrefix());
			}

			if (AllocatorMode == ALLOCATOR_MODE_INFERENCE) {
				string collectionName = StringFormat("%s_Allocator", symbol);

				if (!allocator.LoadModel(AllocatorModelPath, collectionName)) {
					logger.Error("Failed to load allocator model");
					return INIT_FAILED;
				}

				for (int i = 0; i < strategyCount; i++) {
					strategies[i].SetBalance(0);
				}
			}
		}

		logger.Info(StringFormat(
			"%s initialized | symbol: %s | strategies: %d | weight: %.4f | balance: %.2f",
			name,
			symbol,
			strategyCount,
			weight,
			balance
		));

		return INIT_SUCCEEDED;
	}

	virtual int OnTesterInit() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTesterInit();
		}

		return INIT_SUCCEEDED;
	}

	virtual void OnTimer() {
	}

	virtual void OnTick() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTick();
		}
	}

	virtual void OnStartMinute() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartMinute();
		}
	}

	virtual void OnStartHour() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartHour();
		}
	}

	virtual void OnStartDay() {
		runAllocator();

		if (CheckPointer(marketSnapshotsReporter) != POINTER_INVALID)
			marketSnapshotsReporter.AddSnapshot(BuildMarketSnapshot());

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartDay();
		}
	}

	virtual void OnOpenOrder(EOrder &order) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (order.GetSource() == strategies[i].GetPrefix()) {
				strategies[i].OnOpenOrder(order);
				break;
			}
		}
	}

	virtual void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (order.GetSource() == strategies[i].GetPrefix()) {
				strategies[i].OnCloseOrder(order, reason);
				break;
			}
		}
	}

	virtual void OnEnd() {
		int totalEntries = logger.GetEntryCount();

		for (int i = 0; i < ArraySize(strategies); i++) {
			string strategyEntries[];
			strategies[i].GetLogEntries(strategyEntries);
			totalEntries += ArraySize(strategyEntries);
		}

		if (CheckPointer(allocator) != POINTER_INVALID) {
			string allocatorEntries[];
			allocator.GetLogEntries(allocatorEntries);
			totalEntries += ArraySize(allocatorEntries);
		}

		if (totalEntries == 0)
			return;

		SEReportOfLogs exporter;
		exporter.Initialize(GetLogsPath(symbol));

		string assetEntries[];
		logger.GetEntries(assetEntries);
		exporter.Export(StringFormat("%s_Asset", name), assetEntries);
		logger.ClearEntries();

		if (CheckPointer(allocator) != POINTER_INVALID) {
			string allocatorLogEntries[];
			allocator.GetLogEntries(allocatorLogEntries);
			exporter.Export(StringFormat("%s_Allocator", name), allocatorLogEntries);
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			string strategyLogEntries[];
			strategies[i].GetLogEntries(strategyLogEntries);
			exporter.Export(
				StringFormat("%s_%s_Strategy", name, strategies[i].GetPrefix()),
				strategyLogEntries
			);

			strategies[i].OnEnd();
		}
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnDeinit();
		}
	}

	void AddStrategy(SEStrategy *strategy) {
		strategy.SetAsset(GetPointer(this));
		strategy.SetSymbol(symbol);
		strategy.SetMagicNumber(StringToNumber(
			StringFormat(
				"%s_%s_%s",
				symbol,
				name,
				strategy.GetName()
			)
		));

		ArrayResize(strategies, ArraySize(strategies) + 1);
		strategies[ArraySize(strategies) - 1] = strategy;
		isEnabled = true;
	}

	double CalculateQualityProduct() {
		double quality = 1.0;

		for (int i = 0; i < ArraySize(strategies); i++) {
			double strategyQuality =
				strategies[i].GetStatistics().GetQuality().quality;

			if (strategyQuality == 0)
				return 0;

			quality = MathPow(
				quality * strategyQuality,
				0.5
			);
		}

		return quality;
	}

	void CleanupClosedOrders() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].CleanupClosedOrders();
		}
	}

	void ExportAllocatorModel() {
		if (CheckPointer(allocator) == POINTER_INVALID)
			return;

		string collectionName = StringFormat("%s_Allocator", symbol);
		allocator.SaveModel(AllocatorModelPath, collectionName);
	}

	void ExportMarketSnapshots() {
		if (CheckPointer(marketSnapshotsReporter) == POINTER_INVALID)
			return;

		marketSnapshotsReporter.Export();

		logger.Info(StringFormat(
			"Market history exported with %d snapshots",
			marketSnapshotsReporter.GetSnapshotCount()
		));
	}

	void ExportOrderHistory() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].ExportOrderHistory();
		}
	}

	void ExportStrategySnapshots() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].ExportStrategySnapshots();
		}
	}

	bool FindOrderById(string id, int &strategyIndex, int &orderIndex) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			int idx = strategies[i].FindOrderIndexById(id);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	bool FindOrderByOrderId(
		ulong orderId,
		int &strategyIndex,
		int &orderIndex
	) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			int idx = strategies[i].FindOrderIndexByOrderId(orderId);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	bool FindOrderByPositionId(
		ulong positionId,
		int &strategyIndex,
		int &orderIndex
	) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			int idx = strategies[i].FindOrderIndexByPositionId(positionId);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	void PerformStatistics() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].GetStatistics().OnForceEnd();
		}
	}

	void ProcessOrders() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].ProcessOrders();
		}
	}

	SEStrategy * GetStrategyByPrefix(string strategyPrefix) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (strategies[i].GetPrefix() == strategyPrefix)
				return strategies[i];
		}

		return NULL;
	}

	SEStrategy * GetStrategyAtIndex(int index) {
		if (index < 0 || index >= ArraySize(strategies))
			return NULL;

		return strategies[index];
	}

	int GetStrategyCount() {
		return ArraySize(strategies);
	}

	string GetSymbol() {
		return symbol;
	}

	bool IsEnabled() {
		return isEnabled;
	}

	void SetBalance(double newBalance) {
		balance = newBalance;
	}

	void SetDebugLevel(ENUM_DEBUG_LEVEL level) {
		logger.SetDebugLevel(level);

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].SetDebugLevel(level);
		}

		if (CheckPointer(allocator) != POINTER_INVALID)
			allocator.SetDebugLevel(level);
	}

	void SetName(string newName) {
		name = newName;
	}

	void SetSymbol(string newSymbol) {
		symbol = newSymbol;
	}

	void SetWeight(double newWeight) {
		weight = newWeight;
	}
};

#endif
