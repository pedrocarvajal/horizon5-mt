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
	int countOrdersOfToday;
	int countOpenOrders;
	int countClosedOrders;
	EOrder orders[];

	SEAsset *asset;
	SEStatistics *statistics;
	SELotSize *lotSize;
	SEReportOfOrderHistory *orderHistoryReporter;
	SEReportOfStrategySnapshots *strategySnapshotsReporter;
	SEOrderPersistence *orderPersistence;

	void filterOrders(
		EOrder& resultOrders[],
		ENUM_ORDER_TYPE side,
		ENUM_ORDER_STATUSES status,
		ENUM_ORDER_STATUSES defaultStatus1,
		ENUM_ORDER_STATUSES defaultStatus2 = ORDER_STATUS_ANY) {
		ArrayResize(resultOrders, 0);

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
				ArrayResize(resultOrders, ArraySize(resultOrders) + 1);
				resultOrders[ArraySize(resultOrders) - 1] = orders[i];
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

	int RestoreOrders() {
		if (CheckPointer(orderPersistence) == POINTER_INVALID)
			return 0;

		EOrder restoredOrders[];
		int restoredCount = orderPersistence.LoadOrders(restoredOrders);

		if (restoredCount == -1) {
			logger.error(StringFormat(
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
			logger.info(StringFormat("Restored %d orders from JSON", totalRestored));

		return totalRestored;
	}

protected:
	SELogger logger;

	string name;
	string symbol;
	string prefix;
	ulong strategyMagicNumber;

public:
	virtual int OnInit() {
		if (name == "") {
			logger.error("Name not defined for strategy");

			return INIT_FAILED;
		}

		if (symbol == "") {
			logger.error(StringFormat(
				"Symbol not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (prefix == "") {
			logger.error(StringFormat(
				"Prefix not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (strategyMagicNumber == 0) {
			logger.error(StringFormat(
				"Magic number not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (balance <= 0) {
			logger.error(StringFormat(
				"Balance not defined for strategy: %s",
				name
			));

			return INIT_FAILED;
		}

		if (!SymbolSelect(symbol, true)) {
			logger.error(StringFormat(
				"Symbol '%s' does not exist or cannot be selected",
				symbol
			));

			return INIT_FAILED;
		}

		countOrdersOfToday = 0;
		countOpenOrders = 0;
		countClosedOrders = 0;
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

		initializeDefaultThresholds();

		if (isLiveTrading()) {
			orderPersistence = new SEOrderPersistence();
			orderPersistence.Initialize(prefix);
			int restored = RestoreOrders();

			if (restored == -1)
				return INIT_FAILED;
		}

		return INIT_SUCCEEDED;
	}

	virtual int OnTesterInit() {
		return INIT_SUCCEEDED;
	}

	virtual void OnTick() {
	}

	virtual void OnStartMinute() {
	}

	virtual void OnStartHour() {
		statistics.OnStartHour();
	}

	virtual void OnStartDay() {
		if (CheckPointer(strategySnapshotsReporter) != POINTER_INVALID)
			strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());

		statistics.OnStartDay(orders);
		countOrdersOfToday = 0;
	}

	virtual void OnOpenOrder(EOrder& order) {
		statistics.OnOpenOrder(order, orders);
	}

	virtual void OnCloseOrder(EOrder& order, ENUM_DEAL_REASON reason) {
		statistics.OnCloseOrder(order, reason, orders);
		countOpenOrders--;
		countClosedOrders++;

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID)
			orderHistoryReporter.AddOrderSnapshot(order.GetSnapshot());
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(orders); i++) {
			orders[i].OnDeinit();
		}

		ArrayResize(orders, 0);
	}

	void ExportOrderHistory() {
		if (CheckPointer(orderHistoryReporter) == POINTER_INVALID)
			return;

		orderHistoryReporter.Export();

		logger.info(StringFormat(
			"Order history exported with %d orders",
			orderHistoryReporter.GetOrderCount()
		));
	}

	void ExportStrategySnapshots() {
		if (CheckPointer(strategySnapshotsReporter) == POINTER_INVALID)
			return;

		strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());
		strategySnapshotsReporter.Export();

		logger.info(StringFormat(
			"Snapshot history exported with %d snapshots",
			strategySnapshotsReporter.GetSnapshotCount()
		));
	}

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

	EOrder * OpenNewOrder(
		ENUM_ORDER_TYPE side,
		double openAtPrice,
		double volume,
		bool isMarketOrder = true,
		double takeProfit = 0,
		double stopLoss = 0
	) {
		EOrder *order = new EOrder(strategyMagicNumber, symbol);
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
		AddOrder(*order);
		countOrdersOfToday++;
		countOpenOrders++;

		return order;
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

	bool HasActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN ||
			    orders[i].GetStatus() == ORDER_STATUS_PENDING)
				return true;
		}

		return false;
	}

	void CloseAllActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN)
				orders[i].Close();
			else if (orders[i].GetStatus() == ORDER_STATUS_PENDING)
				orders[i].Cancel();
		}
	}

	int GetOrdersCount() {
		return ArraySize(orders);
	}

	EOrder * GetOrderAtIndex(int index) {
		if (index < 0 || index >= ArraySize(orders))
			return NULL;

		return GetPointer(orders[index]);
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

	int FindOrderIndexById(string id) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetId() == id)
				return i;
		}

		return -1;
	}

	void ProcessOrders() {
		SMarketStatus marketStatus = getMarketStatus(symbol);

		for (int i = 0; i < ArraySize(orders); i++) {
			if (!orders[i].IsInitialized())
				orders[i].OnInit();

			if (orders[i].GetStatus() == ORDER_STATUS_PENDING)
				orders[i].CheckToOpen(marketStatus);

			if (orders[i].GetStatus() == ORDER_STATUS_OPEN)
				orders[i].CheckToClose(marketStatus);
		}
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

	void AddOrder(EOrder &order) {
		order.SetPersistence(orderPersistence);
		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = order;
	}

	int GetCountOrdersOfToday() {
		return countOrdersOfToday;
	}

	int GetCountOpenOrders() {
		return countOpenOrders;
	}

	int GetCountClosedOrders() {
		return countClosedOrders;
	}

	double GetLotSizeByStopLoss(double stopLossDistance) {
		double nav = EquityAtRiskCompounded
			? statistics.GetNav()
			: statistics.GetInitialBalance();

		return lotSize.CalculateByStopLoss(nav, stopLossDistance, EquityAtRisk / 100.0);
	}

	ulong GetMagicNumber() {
		return strategyMagicNumber;
	}

	string GetPrefix() {
		return prefix;
	}

	string GetName() {
		return name;
	}

	string GetSymbol() {
		return symbol;
	}

	SEStatistics * GetStatistics() {
		return statistics;
	}

	void SetAsset(SEAsset *assetReference) {
		asset = assetReference;
	}

	virtual void SetWeight(double newWeight) {
		weight = newWeight;
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

	void SetSymbol(string strategySymbol) {
		symbol = strategySymbol;
	}

	void SetPrefix(string strategyPrefix) {
		prefix = strategyPrefix;
	}

	virtual void SetQualityThresholds(SQualityThresholds& thresholds) {
		statistics.SetQualityThresholds(thresholds);
	}
};

#endif
