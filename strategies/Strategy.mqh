#ifndef __SE_STRATEGY_MQH__
#define __SE_STRATEGY_MQH__

class SEAsset;

#include "../constants/time.mqh"

#include "../enums/EOrderStatuses.mqh"
#include "../structs/SSOrderHistory.mqh"
#include "../structs/SSStatisticsSnapshot.mqh"
#include "../structs/STradingStatus.mqh"

#include "../interfaces/IStrategy.mqh"

#include "../services/SELogger/SELogger.mqh"
#include "../services/SEDateTime/SEDateTime.mqh"
#include "../services/SEDateTime/structs/SDateTime.mqh"
#include "../services/SEOrderBook/SEOrderBook.mqh"
#include "../services/SEStatistics/SEStatistics.mqh"
#include "../services/SELotSize/SELotSize.mqh"
#include "../services/SRReportOfOrderHistory/SRReportOfOrderHistory.mqh"
#include "../services/SRReportOfStrategySnapshots/SRReportOfStrategySnapshots.mqh"
#include "../services/SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"
#include "../services/SRPersistenceOfStatistics/SRPersistenceOfStatistics.mqh"
#include "../services/SRPersistenceOfState/SRPersistenceOfState.mqh"

#include "../integrations/HorizonAPI/HorizonAPI.mqh"

#include "../entities/EOrder.mqh"

extern SEDateTime dtime;
extern HorizonAPI horizonAPI;
extern STradingStatus tradingStatus;

void SEOrderBook::NotifyOrderCancelled(EOrder &order) {
	if (CheckPointer(listener) != POINTER_INVALID) {
		listener.OnCancelOrder(order);
	}
}

void SEOrderBook::NotifyOrderPlaced(EOrder &order) {
	if (CheckPointer(listener) != POINTER_INVALID) {
		listener.OnPendingOrderPlaced(order);
	}
}

class SEStrategy:
public IStrategy {
private:
	double weight;
	double balance;

	SEAsset *asset;
	SEStatistics *statistics;
	SELotSize *lotSize;
	SRReportOfOrderHistory *orderHistoryReporter;
	SRReportOfStrategySnapshots *strategySnapshotsReporter;
	SRPersistenceOfOrders *orderPersistence;
	SRPersistenceOfStatistics *statisticsPersistence;
	SRPersistenceOfState *statePersistence;

protected:
	SELogger logger;
	SEOrderBook *orderBook;

	string name;
	string symbol;
	string prefix;
	ulong strategyMagicNumber;
	double maxLotsByOrder;

	void SetStateDouble(string key, double value) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.SetDouble(key, value);
		}
	}

	void GetStateDouble(string key, double &value, double defaultValue = 0.0) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.GetDouble(key, value, defaultValue);
		}
	}

	void SetStateInt(string key, int value) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.SetInt(key, value);
		}
	}

	void GetStateInt(string key, int &value, int defaultValue = 0) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.GetInt(key, value, defaultValue);
		}
	}

	void SetStateString(string key, string value) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.SetString(key, value);
		}
	}

	void GetStateString(string key, string &value, string defaultValue = "") {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.GetString(key, value, defaultValue);
		}
	}

	void SetStateBool(string key, bool value) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.SetBool(key, value);
		}
	}

	void GetStateBool(string key, bool &value, bool defaultValue = false) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.GetBool(key, value, defaultValue);
		}
	}

	void SetStateDatetime(string key, datetime value) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.SetDatetime(key, value);
		}
	}

	void GetStateDatetime(string key, datetime &value, datetime defaultValue = 0) {
		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			statePersistence.GetDatetime(key, value, defaultValue);
		}
	}

public:
	virtual ~SEStrategy() {
		if (CheckPointer(statistics) == POINTER_DYNAMIC) {
			delete statistics;
		}

		if (CheckPointer(lotSize) == POINTER_DYNAMIC) {
			delete lotSize;
		}

		if (CheckPointer(orderHistoryReporter) == POINTER_DYNAMIC) {
			delete orderHistoryReporter;
		}

		if (CheckPointer(strategySnapshotsReporter) == POINTER_DYNAMIC) {
			delete strategySnapshotsReporter;
		}

		if (CheckPointer(orderPersistence) == POINTER_DYNAMIC) {
			delete orderPersistence;
		}

		if (CheckPointer(statisticsPersistence) == POINTER_DYNAMIC) {
			delete statisticsPersistence;
		}

		if (CheckPointer(statePersistence) == POINTER_DYNAMIC) {
			delete statePersistence;
		}

		if (CheckPointer(orderBook) == POINTER_DYNAMIC) {
			delete orderBook;
		}
	}

	void ExportOrderHistory() {
		if (CheckPointer(orderHistoryReporter) == POINTER_INVALID) {
			return;
		}

		orderHistoryReporter.Export();

		logger.Info(StringFormat(
			"Order history exported with %d orders",
			orderHistoryReporter.GetOrderCount()
		));
	}

	void ExportStrategySnapshots() {
		if (CheckPointer(strategySnapshotsReporter) == POINTER_INVALID) {
			return;
		}

		if (CheckPointer(statistics) != POINTER_DYNAMIC) {
			return;
		}

		strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());
		strategySnapshotsReporter.Export();

		logger.Info(StringFormat(
			"Snapshot history exported with %d snapshots",
			strategySnapshotsReporter.GetSnapshotCount()
		));
	}

	double GetBalance() {
		return balance;
	}

	double GetLotSizeByStopLoss(double stopLossDistance) {
		if (balance <= 0) {
			return -1;
		}

		double nav = EquityAtRiskCompounded
			? statistics.GetNav()
			: balance;

		double result = lotSize.CalculateByStopLoss(nav, stopLossDistance, EquityAtRisk / 100.0);

		if (maxLotsByOrder > 0 && result > maxLotsByOrder) {
			result = maxLotsByOrder;
		}

		return result;
	}

	ulong GetMagicNumber() {
		return strategyMagicNumber;
	}

	double GetMaxLotsByOrder() {
		return maxLotsByOrder;
	}

	string GetName() {
		return name;
	}

	SEOrderBook * GetOrderBook() {
		return orderBook;
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

	double GetWeight() {
		return weight;
	}

	virtual void OnCancelOrder(EOrder& order) {
		orderBook.OnOrderCancelled();
		horizonAPI.UpsertOrder(order);

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
			orderHistoryReporter.AddOrderSnapshot(order.GetSnapshot());
		}
	}

	virtual void OnCloseOrder(EOrder& order, ENUM_DEAL_REASON reason) {
		statistics.OnCloseOrder(order, orderBook.orders);
		orderBook.OnOrderClosed();

		if (CheckPointer(statisticsPersistence) == POINTER_DYNAMIC) {
			statisticsPersistence.Save(statistics);
		}

		horizonAPI.UpsertOrder(order);

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
			orderHistoryReporter.AddOrderSnapshot(order.GetSnapshot());
		}

		detectManualClose(reason);
	}

	virtual void OnDeinit() {
		if (CheckPointer(statisticsPersistence) == POINTER_DYNAMIC) {
			statisticsPersistence.Save(statistics);
		}

		if (CheckPointer(orderBook) == POINTER_DYNAMIC) {
			orderBook.OnDeinit();
		}
	}

	virtual void OnEnd() {
	}

	virtual int OnInit() {
		int validationResult = validateConfiguration();
		if (validationResult != INIT_SUCCEEDED) {
			return validationResult;
		}

		initializeServices();

		if (IsLiveTrading()) {
			orderPersistence = new SRPersistenceOfOrders();
			orderPersistence.Initialize(symbol, prefix);
			orderBook.SetPersistence(orderPersistence);

			int restored = restoreOrders();

			if (restored == -1) {
				return INIT_FAILED;
			}

			statisticsPersistence = new SRPersistenceOfStatistics();
			statisticsPersistence.Initialize(symbol, prefix);
			statisticsPersistence.Load(statistics);

			statePersistence = new SRPersistenceOfState();
			statePersistence.Initialize(symbol, prefix);
			statePersistence.Load();
		}

		return INIT_SUCCEEDED;
	}

	virtual void OnOpenOrder(EOrder& order) {
		statistics.OnOpenOrder(order, orderBook.orders);
		horizonAPI.UpsertOrder(order);
	}

	virtual void OnPendingOrderPlaced(EOrder& order) {
		horizonAPI.UpsertOrder(order);
	}

	virtual void OnStartDay() {
		orderBook.PurgeClosedOrders();

		if (CheckPointer(strategySnapshotsReporter) != POINTER_INVALID) {
			strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());
		}

		statistics.OnStartDay(orderBook.orders);

		if (CheckPointer(statisticsPersistence) == POINTER_DYNAMIC) {
			statisticsPersistence.Save(statistics);
		}

		orderBook.ResetTodayOrderCount();
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

	virtual void OnTimer() {
	}

	void ProcessOrders() {
		orderBook.ProcessOrders();
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

	void SetMaxLotsByOrder(double lots) {
		maxLotsByOrder = lots;
	}

	void SetName(string strategyName) {
		name = strategyName;
	}

	void SetPrefix(string strategyPrefix) {
		prefix = strategyPrefix;
	}

	void SetSymbol(string strategySymbol) {
		symbol = strategySymbol;
	}

	virtual void SetWeight(double newWeight) {
		weight = newWeight;
	}

	void SyncOrders() {
		for (int i = 0; i < orderBook.GetOrdersCount(); i++) {
			EOrder *order = orderBook.GetOrderAtIndex(i);
			if (order != NULL && (order.GetStatus() == ORDER_STATUS_OPEN ||
					      order.GetStatus() == ORDER_STATUS_PENDING)) {
				horizonAPI.UpsertOrder(order);
			}
		}
	}

	void SyncSnapshot() {
		double floatingPnl;
		double exposureLots;
		double exposureUsd;
		double nav;
		double drawdownPct;

		calculateLiveMetrics(floatingPnl, exposureLots, exposureUsd, nav, drawdownPct);

		horizonAPI.StoreStrategySnapshot(
			strategyMagicNumber,
			nav,
			drawdownPct,
			statistics.GetDailyPerformance(),
			floatingPnl,
			orderBook.GetOpenOrderCount(),
			exposureLots,
			exposureUsd
		);
	}

private:
	void calculateLiveMetrics(
		double &floatingPnl,
		double &exposureLots,
		double &exposureUsd,
		double &nav,
		double &drawdownPct
	) {
		floatingPnl = 0;
		exposureLots = 0;
		exposureUsd = 0;

		double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

		for (int i = 0; i < orderBook.GetOrdersCount(); i++) {
			EOrder *order = orderBook.GetOrderAtIndex(i);
			if (order != NULL && order.GetStatus() == ORDER_STATUS_OPEN) {
				floatingPnl += orderBook.GetFloatingProfitAndLoss(order);
				exposureLots += order.GetVolume();
				exposureUsd += order.GetVolume() * contractSize * SymbolInfoDouble(symbol, SYMBOL_BID);
			}
		}

		nav = statistics.GetClosedNav() + floatingPnl;
		double peak = statistics.GetNavPeak();

		if (nav > peak) {
			peak = nav;
		}

		drawdownPct = (peak > 0 && nav < peak)
			? (peak - nav) / peak
			: 0.0;
	}

	void detectManualClose(ENUM_DEAL_REASON reason) {
		if (tradingStatus.isPaused) {
			return;
		}

		if (reason != DEAL_REASON_CLIENT &&
		    reason != DEAL_REASON_MOBILE &&
		    reason != DEAL_REASON_WEB) {
			return;
		}

		tradingStatus.isPaused = true;
		tradingStatus.reason = TRADING_PAUSE_REASON_MANUAL_CLOSE;
		logger.Warning("Manual close detected - trading paused until next day");
	}

	void initializeServices() {
		logger.SetPrefix(name);
		statistics = new SEStatistics(balance);
		lotSize = new SELotSize(symbol);

		orderBook = new SEOrderBook();
		orderBook.Initialize(symbol, prefix, strategyMagicNumber);
		orderBook.SetListener(GetPointer(this));

		if (EnableOrderHistoryReport) {
			string reportName = StringFormat("%s_%s_Orders", symbol, prefix);
			orderHistoryReporter = new SRReportOfOrderHistory(symbol, reportName);
		}

		if (EnableSnapshotHistoryReport) {
			string reportName = StringFormat("%s_%s_Snapshots", symbol, prefix);
			strategySnapshotsReporter = new SRReportOfStrategySnapshots(symbol, name, prefix, reportName);
		}
	}

	int restoreOrders() {
		EOrder reconciledOrders[];
		int totalRestored = orderBook.RestoreOrders(reconciledOrders);

		if (totalRestored == -1) {
			return -1;
		}

		for (int i = orderBook.GetOrdersCount() - totalRestored; i < orderBook.GetOrdersCount(); i++) {
			EOrder *addedOrder = orderBook.GetOrderAtIndex(i);

			if (addedOrder != NULL) {
				OnOpenOrder(addedOrder);
			}
		}

		for (int i = 0; i < ArraySize(reconciledOrders); i++) {
			horizonAPI.UpsertOrder(reconciledOrders[i]);
			logger.Info(StringFormat(
				"Synced reconciled order to HorizonAPI: %s",
				reconciledOrders[i].GetId()
			));
		}

		if (totalRestored > 0) {
			logger.Info(StringFormat("Restored %d active orders from JSON", totalRestored));
		}

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
