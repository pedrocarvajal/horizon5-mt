#ifndef __SE_STRATEGY_MQH__
#define __SE_STRATEGY_MQH__

class SEAsset;

#include "../enums/EOrderStatuses.mqh"
#include "../structs/SSOrderHistory.mqh"
#include "../structs/SSStatisticsSnapshot.mqh"
#include "../structs/SQualityThresholds.mqh"

#include "../interfaces/IStrategy.mqh"
#include "../services/SELogger/SELogger.mqh"
#include "../services/SEDateTime/SEDateTime.mqh"
#include "../services/SEDateTime/structs/SDateTime.mqh"
#include "../entities/EOrder.mqh"
#include "../services/SEStatistics/SEStatistics.mqh"
#include "../services/SELotSize/SELotSize.mqh"
#include "../services/SEReportOfOrderHistory/SEReportOfOrderHistory.mqh"
#include "../services/SEReportOfStrategySnapshots/SEReportOfStrategySnapshots.mqh"
#include "../services/SEOrderPersistence/SEOrderPersistence.mqh"

#define ORDER_TYPE_ANY    -1
#define ORDER_STATUS_ANY  -1

extern SEDateTime dtime;

class SEStrategy:
public IStrategy {
private:
	double weight;
	double balance;
	int todayOrderCount;
	int openOrderCount;
	int closedOrderCount;
	EOrder orders[];

	SEAsset *asset;
	SEStatistics *statistics;
	SELotSize *lotSize;
	SEReportOfOrderHistory *orderHistoryReporter;
	SEReportOfStrategySnapshots *strategySnapshotsReporter;
	SEOrderPersistence *orderPersistence;

protected:
	SELogger logger;

	string name;
	string symbol;
	string prefix;
	ulong strategyMagicNumber;

public:
	virtual ~SEStrategy() {
		if (CheckPointer(statistics) == POINTER_DYNAMIC)
			delete statistics;

		if (CheckPointer(lotSize) == POINTER_DYNAMIC)
			delete lotSize;

		if (CheckPointer(orderHistoryReporter) == POINTER_DYNAMIC)
			delete orderHistoryReporter;

		if (CheckPointer(strategySnapshotsReporter) == POINTER_DYNAMIC)
			delete strategySnapshotsReporter;

		if (CheckPointer(orderPersistence) == POINTER_DYNAMIC)
			delete orderPersistence;
	}

	void AddOrder(EOrder &order) {
		order.SetPersistence(orderPersistence);
		int count = ArraySize(orders);
		ArrayResize(orders, count + 1, 16);
		orders[count] = order;
	}

	void CleanupClosedOrders() {
		int writeIndex = 0;

		for (int i = 0; i < ArraySize(orders); i++) {
			if (
				orders[i].GetStatus() == ORDER_STATUS_CLOSED ||
				orders[i].GetStatus() == ORDER_STATUS_CANCELLED
			) {
				orders[i].OnDeinit();
			} else {
				if (writeIndex != i)
					orders[writeIndex] = orders[i];
				writeIndex++;
			}
		}

		ArrayResize(orders, writeIndex);
	}

	void CloseAllActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN)
				orders[i].Close();
			else if (orders[i].GetStatus() == ORDER_STATUS_PENDING)
				orders[i].Cancel();
		}
	}

	void ExportOrderHistory() {
		if (CheckPointer(orderHistoryReporter) == POINTER_INVALID)
			return;

		orderHistoryReporter.Export();

		logger.Info(StringFormat(
			"Order history exported with %d orders",
			orderHistoryReporter.GetOrderCount()
		));
	}

	void ExportStrategySnapshots() {
		if (CheckPointer(strategySnapshotsReporter) == POINTER_INVALID)
			return;

		strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());
		strategySnapshotsReporter.Export();

		logger.Info(StringFormat(
			"Snapshot history exported with %d snapshots",
			strategySnapshotsReporter.GetSnapshotCount()
		));
	}

	int FindOrderIndexById(string id) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetId() == id)
				return i;
		}

		return -1;
	}

	int FindOrderIndexByOrderId(ulong orderId) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetOrderId() == orderId)
				return i;
		}

		return -1;
	}

	int FindOrderIndexByPositionId(ulong positionId) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetPositionId() == positionId)
				return i;
		}

		return -1;
	}

	double GetBalance() {
		return balance;
	}

	int GetClosedOrderCount() {
		return closedOrderCount;
	}

	void GetLogEntries(string &result[]) {
		logger.GetEntries(result);
	}

	double GetLotSizeByStopLoss(double stopLossDistance) {
		if (balance <= 0)
			return 0;

		double nav = EquityAtRiskCompounded
			? statistics.GetNav()
			: balance;

		return lotSize.CalculateByStopLoss(nav, stopLossDistance, EquityAtRisk / 100.0);
	}

	ulong GetMagicNumber() {
		return strategyMagicNumber;
	}

	string GetName() {
		return name;
	}

	int GetOpenOrderCount() {
		return openOrderCount;
	}

	void GetOpenOrders(
		EOrder& resultOrders[],
		ENUM_ORDER_TYPE side = ORDER_TYPE_ANY,
		ENUM_ORDER_STATUSES status = ORDER_STATUS_ANY
	) {
		filterOrders(
			resultOrders,
			side,
			status,
			ORDER_STATUS_OPEN,
			ORDER_STATUS_PENDING
		);
	}

	EOrder * GetOrderAtIndex(int index) {
		if (index < 0 || index >= ArraySize(orders))
			return NULL;

		return GetPointer(orders[index]);
	}

	int GetOrdersCount() {
		return ArraySize(orders);
	}

	string GetPrefix() {
		return prefix;
	}

	SEStatistics * GetStatistics() {
		return statistics;
	}

	string GetSymbol() {
		return symbol;
	}

	int GetTodayOrderCount() {
		return todayOrderCount;
	}

	double GetWeight() {
		return weight;
	}

	bool HasActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN ||
			    orders[i].GetStatus() == ORDER_STATUS_PENDING)
				return true;
		}

		return false;
	}

	virtual void OnCloseOrder(EOrder& order, ENUM_DEAL_REASON reason) {
		statistics.OnCloseOrder(order, reason, orders);
		openOrderCount--;
		closedOrderCount++;

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID)
			orderHistoryReporter.AddOrderSnapshot(order.GetSnapshot());
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(orders); i++) {
			orders[i].OnDeinit();
		}

		ArrayResize(orders, 0);
	}

	virtual void OnEnd() {
	}

	virtual int OnInit() {
		int validationResult = validateConfiguration();
		if (validationResult != INIT_SUCCEEDED)
			return validationResult;

		initializeServices();
		initializeDefaultThresholds();

		if (IsLiveTrading()) {
			orderPersistence = new SEOrderPersistence();
			orderPersistence.Initialize(prefix);
			int restored = restoreOrders();

			if (restored == -1)
				return INIT_FAILED;
		}

		return INIT_SUCCEEDED;
	}

	virtual void OnOpenOrder(EOrder& order) {
		statistics.OnOpenOrder(order, orders);
	}

	virtual void OnStartDay() {
		if (CheckPointer(strategySnapshotsReporter) != POINTER_INVALID)
			strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());

		statistics.OnStartDay(orders);
		todayOrderCount = 0;
	}

	virtual void OnStartHour() {
		statistics.OnStartHour();
	}

	virtual void OnStartMinute() {
	}

	virtual int OnTesterInit() {
		return INIT_SUCCEEDED;
	}

	virtual void OnTick() {
	}

	EOrder * OpenNewOrder(
		ENUM_ORDER_TYPE side,
		double openAtPrice,
		double volume,
		bool isMarketOrder = true,
		double takeProfit = 0,
		double stopLoss = 0
	) {
		if (balance <= 0) {
			logger.Debug("New order blocked - no balance allocated");
			return NULL;
		}

		EOrder order(strategyMagicNumber, symbol);
		double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
		double currentPrice = (side == ORDER_TYPE_BUY) ? askPrice : bidPrice;

		order.SetStatus(ORDER_STATUS_PENDING);
		order.SetSource(prefix);
		order.SetSide(side);
		order.SetVolume(volume);
		order.SetSignalPrice(currentPrice);
		order.SetOpenAtPrice(openAtPrice);
		SDateTime signalTime = dtime.Now();
		order.SetSignalAt(signalTime);
		order.SetIsMarketOrder(isMarketOrder);

		if (stopLoss > 0)
			order.SetStopLoss(stopLoss);

		if (takeProfit > 0)
			order.SetTakeProfit(takeProfit);

		order.GetId();
		AddOrder(order);
		todayOrderCount++;
		openOrderCount++;

		return GetOrderAtIndex(GetOrdersCount() - 1);
	}

	void ProcessOrders() {
		SMarketStatus marketStatus = GetMarketStatus(symbol);

		for (int i = 0; i < ArraySize(orders); i++) {
			if (!orders[i].IsInitialized())
				orders[i].OnInit();

			if (orders[i].GetStatus() == ORDER_STATUS_PENDING)
				orders[i].CheckToOpen(marketStatus);

			if (orders[i].GetStatus() == ORDER_STATUS_OPEN)
				orders[i].CheckToClose(marketStatus);
		}
	}

	void SetAsset(SEAsset *assetReference) {
		asset = assetReference;
	}

	virtual void SetBalance(double newBalance) {
		balance = newBalance;
	}

	void SetMagicNumber(ulong magic) {
		strategyMagicNumber = magic;
	}

	void SetName(string strategyName) {
		name = strategyName;
	}

	void SetPrefix(string strategyPrefix) {
		prefix = strategyPrefix;
	}

	virtual void SetQualityThresholds(SQualityThresholds& thresholds) {
		statistics.SetQualityThresholds(thresholds);
	}

	void SetSymbol(string strategySymbol) {
		symbol = strategySymbol;
	}

	virtual void SetWeight(double newWeight) {
		weight = newWeight;
	}

private:
	void filterOrders(
		EOrder& resultOrders[],
		ENUM_ORDER_TYPE side,
		ENUM_ORDER_STATUSES status,
		ENUM_ORDER_STATUSES defaultStatus1,
		ENUM_ORDER_STATUSES defaultStatus2 = ORDER_STATUS_ANY) {
		ArrayResize(resultOrders, 0, ArraySize(orders));

		int resultCount = 0;

		for (int i = 0; i < ArraySize(orders); i++) {
			bool isSideMatch = (side == ORDER_TYPE_ANY) || (orders[i].GetSide() == side);
			bool isStatusMatch = false;

			if (status == ORDER_STATUS_ANY) {
				isStatusMatch = (orders[i].GetStatus() == defaultStatus1);
				if (defaultStatus2 != ORDER_STATUS_ANY)
					isStatusMatch = isStatusMatch || (orders[i].GetStatus() == defaultStatus2);
			} else {
				isStatusMatch = (orders[i].GetStatus() == status);
			}

			if (isSideMatch && isStatusMatch) {
				resultCount++;
				ArrayResize(resultOrders, resultCount);
				resultOrders[resultCount - 1] = orders[i];
			}
		}
	}

	void initializeDefaultThresholds() {
		SQualityThresholds thresholds;

		thresholds.optimizationFormula = OPTIMIZATION_BY_PERFORMANCE;
		thresholds.expectedTotalReturnPctByMonth = 0.05;
		thresholds.expectedMaxDrawdownPct = 0.25;
		thresholds.expectedWinRate = 0.50;
		thresholds.expectedRecoveryFactor = 2;
		thresholds.expectedRiskRewardRatio = 2;
		thresholds.expectedRSquared = 0.85;
		thresholds.expectedTrades = 10;
		thresholds.minTotalReturnPct = 0.0;
		thresholds.maxMaxDrawdownPct = 0.30;
		thresholds.minWinRate = 0.40;
		thresholds.minRiskRewardRatio = 1;
		thresholds.minRecoveryFactor = 1;
		thresholds.minRSquared = 0.0;
		thresholds.minTrades = 5;

		SetQualityThresholds(thresholds);
	}

	void initializeServices() {
		todayOrderCount = 0;
		openOrderCount = 0;
		closedOrderCount = 0;
		logger.SetPrefix(name);
		statistics = new SEStatistics(symbol, name, prefix, balance);
		lotSize = new SELotSize(symbol);

		if (EnableOrderHistoryReport) {
			string reportName = StringFormat("%s_%s_Orders", symbol, prefix);
			orderHistoryReporter = new SEReportOfOrderHistory(symbol, reportName);
		}

		if (EnableSnapshotHistoryReport) {
			string reportName = StringFormat("%s_%s_Snapshots", symbol, prefix);
			strategySnapshotsReporter = new SEReportOfStrategySnapshots(symbol, name, prefix, reportName);
		}
	}

	int restoreOrders() {
		if (CheckPointer(orderPersistence) == POINTER_INVALID)
			return 0;

		EOrder restoredOrders[];
		int restoredCount = orderPersistence.LoadOrders(restoredOrders);

		if (restoredCount == -1) {
			logger.Error(StringFormat(
				"Failed to restore orders for strategy: %s",
				prefix
			));

			return -1;
		}

		int totalRestored = 0;

		for (int i = 0; i < restoredCount; i++) {
			if (FindOrderIndexById(restoredOrders[i].GetId()) != -1)
				continue;

			restoredOrders[i].OnInit();
			AddOrder(restoredOrders[i]);
			totalRestored++;

			EOrder *addedOrder = GetOrderAtIndex(GetOrdersCount() - 1);

			if (addedOrder != NULL)
				OnOpenOrder(addedOrder);
		}

		if (totalRestored > 0)
			logger.Info(StringFormat("Restored %d orders from JSON", totalRestored));

		return totalRestored;
	}

	int validateConfiguration() {
		if (name == "") {
			logger.Error("Name not defined for strategy");

			return INIT_FAILED;
		}

		if (symbol == "") {
			logger.Error(StringFormat(
				"Symbol not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (prefix == "") {
			logger.Error(StringFormat(
				"Prefix not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (strategyMagicNumber == 0) {
			logger.Error(StringFormat(
				"Magic number not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (balance <= 0) {
			logger.Error(StringFormat(
				"Balance not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (!SymbolSelect(symbol, true)) {
			logger.Error(StringFormat(
				"Symbol '%s' does not exist or cannot be selected",
				symbol
			));

			return INIT_FAILED;
		}

		return INIT_SUCCEEDED;
	}
};

#endif
