#ifndef __SE_STRATEGY_MQH__
#define __SE_STRATEGY_MQH__

#include "../constants/COTime.mqh"

#include "../enums/EOrderStatuses.mqh"

#include "../structs/SSOrderHistory.mqh"
#include "../structs/SSStatisticsSnapshot.mqh"
#include "../structs/STradingStatus.mqh"

#include "../helpers/sqx/HNormalizeLotSize.mqh"

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
#include "../services/SRImplementationOfHorizonMonitor/SRImplementationOfHorizonMonitor.mqh"
#include "../services/SRReportOfMonitorSeed/SRReportOfMonitorSeed.mqh"

#include "../entities/EOrder.mqh"

extern SEDateTime dtime;
extern SRImplementationOfHorizonMonitor horizonMonitor;
extern STradingStatus tradingStatus;
extern SRReportOfMonitorSeed *monitorSeedReporter;

class SEStrategy:
public IStrategy {
private:
	double weight;
	double balance;

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
	string strategyUuid;
	ulong strategyMagicNumber;
	double maxLotsByOrder;
	bool isPassive;

	void SetStateDouble(string key, double value) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.SetDouble(key, value);
		}
	}

	void GetStateDouble(string key, double &value, double defaultValue = 0.0) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.GetDouble(key, value, defaultValue);
		}
	}

	void SetStateInt(string key, int value) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.SetInt(key, value);
		}
	}

	void GetStateInt(string key, int &value, int defaultValue = 0) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.GetInt(key, value, defaultValue);
		}
	}

	void SetStateString(string key, string value) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.SetString(key, value);
		}
	}

	void GetStateString(string key, string &value, string defaultValue = "") {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.GetString(key, value, defaultValue);
		}
	}

	void SetStateBool(string key, bool value) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.SetBool(key, value);
		}
	}

	void GetStateBool(string key, bool &value, bool defaultValue = false) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.GetBool(key, value, defaultValue);
		}
	}

	void SetStateDatetime(string key, datetime value) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
			statePersistence.SetDatetime(key, value);
		}
	}

	void GetStateDatetime(string key, datetime &value, datetime defaultValue = 0) {
		if (CheckPointer(statePersistence) != POINTER_INVALID) {
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

		logger.Info(LOG_CODE_STATS_EXPORT_FAILED, StringFormat(
			"order history exported | strategy=%s count=%d",
			name,
			orderHistoryReporter.GetOrderCount()
		));
	}

	void ExportStrategySnapshots() {
		if (CheckPointer(strategySnapshotsReporter) == POINTER_INVALID) {
			return;
		}

		if (CheckPointer(statistics) == POINTER_INVALID) {
			return;
		}

		strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());
		strategySnapshotsReporter.Export();

		logger.Info(LOG_CODE_STATS_EXPORT_FAILED, StringFormat(
			"snapshot history exported | strategy=%s count=%d",
			name,
			strategySnapshotsReporter.GetSnapshotCount()
		));
	}

	double GetBalance() {
		return balance;
	}

	double CalculateLotSize(double stopLossDistance) {
		double orderLotSize = GetLotSizeByStopLoss(stopLossDistance);

		if (orderLotSize < 0) {
			return -1;
		}

		if (orderLotSize == 0) {
			logger.Warning(LOG_CODE_VALIDATION_VOLUME_INVALID, StringFormat(
				"lot size invalid | strategy=%s symbol=%s reason='calculation returned zero'",
				name, symbol
			));
			return 0;
		}

		orderLotSize = NormalizeLotSize(orderLotSize, symbol);

		if (orderLotSize == 0) {
			logger.Warning(LOG_CODE_VALIDATION_LOT_BELOW_MIN, StringFormat(
				"lot size below minimum | strategy=%s symbol=%s reason='normalized volume below broker minimum'",
				name, symbol
			));
			return 0;
		}

		return orderLotSize;
	}

	double GetLotSizeByStopLoss(double stopLossDistance) {
		if (balance <= 0) {
			return 0;
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

	string GetStrategyUuid() {
		return strategyUuid;
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

	double GetTodayClosedPnl() {
		return statistics.GetTodayClosedPnl();
	}

	double GetTodayTotalPnl() {
		EOrder ordersSnapshot[];
		orderBook.CopyOrders(ordersSnapshot);
		return statistics.GetTodayTotalPnl(ordersSnapshot);
	}

	double GetWeight() {
		return weight;
	}

	bool IsPassive() {
		return isPassive;
	}

	bool IsTradable() {
		return CheckPointer(statistics) == POINTER_INVALID || statistics.GetClosedNav() > 0;
	}

	bool CanTrade() {
		return !tradingStatus.isPaused && IsTradable();
	}

	virtual void OnCancelOrder(EOrder& order) {
		horizonMonitor.UpsertOrder(order);

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
			orderHistoryReporter.AddOrderSnapshot(order.GetSnapshot());
		}

		if (CheckPointer(monitorSeedReporter) != POINTER_INVALID && !isPassive) {
			monitorSeedReporter.AddOrder(order);
		}
	}

	virtual void OnCloseOrder(EOrder& order, ENUM_DEAL_REASON reason) {
		EOrder ordersSnapshot[];
		orderBook.CopyOrders(ordersSnapshot);
		statistics.OnCloseOrder(order, ordersSnapshot);

		if (CheckPointer(statisticsPersistence) != POINTER_INVALID) {
			statisticsPersistence.Save(statistics);
		}

		horizonMonitor.UpsertOrder(order);

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
			orderHistoryReporter.AddOrderSnapshot(order.GetSnapshot());
		}

		if (CheckPointer(monitorSeedReporter) != POINTER_INVALID && !isPassive) {
			monitorSeedReporter.AddOrder(order);
		}

		detectManualClose(reason);
	}

	virtual void OnDeinit() {
		if (CheckPointer(statisticsPersistence) != POINTER_INVALID) {
			statisticsPersistence.Save(statistics);
		}

		if (CheckPointer(orderBook) != POINTER_INVALID) {
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
		EOrder ordersSnapshot[];
		orderBook.CopyOrders(ordersSnapshot);
		statistics.OnOpenOrder(order, ordersSnapshot);
		horizonMonitor.UpsertOrder(order);
	}

	virtual void OnOrderUpdated(EOrder& order) {
		horizonMonitor.UpsertOrder(order);
	}

	virtual void OnPendingOrderPlaced(EOrder& order) {
		horizonMonitor.UpsertOrder(order);
	}

	virtual void OnStartDay() {
		orderBook.PurgeClosedOrders();

		if (CheckPointer(strategySnapshotsReporter) != POINTER_INVALID) {
			strategySnapshotsReporter.AddSnapshot(statistics.GetDailySnapshot());
		}

		EOrder ordersSnapshot[];
		orderBook.CopyOrders(ordersSnapshot);
		statistics.OnStartDay(ordersSnapshot);

		if (CheckPointer(statisticsPersistence) != POINTER_INVALID) {
			statisticsPersistence.Save(statistics);
		}
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

	virtual void SetBalance(double newBalance) {
		balance = newBalance;
	}

	void SetMagicNumber(ulong magic) {
		strategyMagicNumber = magic;
	}

	void SetStrategyUuid(string uuid) {
		strategyUuid = uuid;
	}

	void SetMaxLotsByOrder(double lots) {
		maxLotsByOrder = lots;
	}

	void SetName(string strategyName) {
		name = strategyName;
	}

	void SetPassive(bool passive) {
		isPassive = passive;
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

	void SyncSnapshot(string event) {
		double floatingPnl = 0;

		for (int i = 0; i < orderBook.GetOrdersCount(); i++) {
			EOrder *order = orderBook.GetOrderAtIndex(i);
			if (order != NULL && order.GetStatus() == ORDER_STATUS_OPEN) {
				floatingPnl += order.GetFloatingPnL();
			}
		}

		double realizedPnl = statistics.GetClosedNav() - statistics.GetInitialBalance();
		double equity = balance + floatingPnl;

		horizonMonitor.StoreStrategySnapshot(
			strategyMagicNumber,
			balance,
			equity,
			floatingPnl,
			realizedPnl,
			event
		);
	}

private:
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
		logger.Warning(LOG_CODE_TRADING_PAUSED, StringFormat(
			"trading paused | strategy=%s reason='manual close detected' until='next day'",
			name
		));
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
			horizonMonitor.UpsertOrder(reconciledOrders[i]);
			logger.Info(LOG_CODE_ORDER_RESTORED, StringFormat(
				"order reconciled | strategy=%s order_id=%s target=monitor",
				name,
				reconciledOrders[i].GetId()
			));
		}

		if (totalRestored > 0) {
			logger.Info(LOG_CODE_ORDER_RESTORED, StringFormat(
				"orders restored | strategy=%s count=%d",
				name,
				totalRestored
			));
		}

		return totalRestored;
	}

	int validateConfiguration() {
		if (name == "") {
			logger.Error(LOG_CODE_CONFIG_INVALID_PARAMETER, "configuration invalid | field=name reason='strategy name not defined'");

			return INIT_FAILED;
		}

		if (symbol == "") {
			logger.Error(LOG_CODE_CONFIG_INVALID_SYMBOL, StringFormat(
				"configuration invalid | strategy=%s field=symbol reason='symbol not defined'",
				name
			));

			return INIT_FAILED;
		}

		if (prefix == "") {
			logger.Error(LOG_CODE_CONFIG_INVALID_PARAMETER, StringFormat(
				"configuration invalid | strategy=%s field=prefix reason='prefix not defined'",
				name
			));

			return INIT_FAILED;
		}

		if (strategyMagicNumber == 0) {
			logger.Error(LOG_CODE_CONFIG_INVALID_PARAMETER, StringFormat(
				"configuration invalid | strategy=%s field=magic_number reason='magic number not defined'",
				name
			));

			return INIT_FAILED;
		}

		if (isPassive) {
			return INIT_SUCCEEDED;
		}

		if (balance <= 0) {
			logger.Error(LOG_CODE_CONFIG_INVALID_PARAMETER, StringFormat(
				"configuration invalid | strategy=%s field=balance reason='balance not defined'",
				name
			));

			return INIT_FAILED;
		}

		if (!SymbolSelect(symbol, true)) {
			logger.Error(LOG_CODE_CONFIG_INVALID_SYMBOL, StringFormat(
				"configuration invalid | strategy=%s symbol=%s reason='symbol not available in market watch'",
				name, symbol
			));

			return INIT_FAILED;
		}

		return INIT_SUCCEEDED;
	}
};

#endif
