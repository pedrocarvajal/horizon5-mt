#ifndef __SE_ASSET_MQH__
#define __SE_ASSET_MQH__

#include "../interfaces/IAsset.mqh"

#include "../helpers/HStringToNumber.mqh"
#include "../helpers/HGetAssetRate.mqh"
#include "../helpers/HGetSnapshotEvent.mqh"

#include "../services/SELogger/SELogger.mqh"
#include "../services/SRReportOfMarketSnapshots/SRReportOfMarketSnapshots.mqh"
#include "../services/SRReportOfMonitorSeed/SRReportOfMonitorSeed.mqh"

#include "../services/SRImplementationOfHorizonMonitor/SRImplementationOfHorizonMonitor.mqh"
#include "../services/SRImplementationOfHorizonGateway/SRImplementationOfHorizonGateway.mqh"
#include "../services/SRRemoteOrderManager/SRRemoteOrderManager.mqh"

#include "../entities/EOrder.mqh"

#include "../indicators/INRollingReturn.mqh"
#include "../indicators/INDrawdownFromPeak.mqh"
#include "../indicators/INVolatility.mqh"

#include "../strategies/Strategy.mqh"

extern SEDateTime dtime;
extern SRImplementationOfHorizonMonitor horizonMonitor;
extern SRImplementationOfHorizonGateway horizonGateway;
extern SRReportOfMonitorSeed *monitorSeedReporter;

#define ROLLING_PERIOD_DAYS 90

class SEAsset:
public IAsset {
private:
	SELogger logger;
	SRReportOfMarketSnapshots *marketSnapshotsReporter;
	SRRemoteOrderManager remoteOrderManager;

	string name;
	double weight;
	bool isEnabled;
	double balance;

	SEStrategy *strategies[];

	SSMarketSnapshot BuildMarketSnapshot() {
		SSMarketSnapshot snapshot;
		snapshot.timestamp = dtime.Timestamp();
		snapshot.bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		snapshot.ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		snapshot.spread = snapshot.ask - snapshot.bid;
		snapshot.rollingPerformance = RollingReturn(symbol, PERIOD_D1, ROLLING_PERIOD_DAYS, 0);
		snapshot.rollingDrawdown = DrawdownFromPeak(symbol, PERIOD_D1, ROLLING_PERIOD_DAYS, 0);
		snapshot.rollingVolatility = Volatility(symbol, PERIOD_D1, ROLLING_PERIOD_DAYS, 0);
		return snapshot;
	}

	int initializeStrategies(int strategyCount) {
		int activeCount = 0;

		for (int i = 0; i < strategyCount; i++) {
			if (!strategies[i].IsPassive()) {
				activeCount++;
			}
		}

		double weightPerStrategy = activeCount > 0 ? weight / activeCount : 0;
		double balancePerStrategy = activeCount > 0 ? balance / activeCount : 0;

		for (int i = 0; i < strategyCount; i++) {
			if (strategies[i].IsPassive()) {
				strategies[i].SetWeight(weight);
				strategies[i].SetBalance(balance);
			} else {
				strategies[i].SetWeight(weightPerStrategy);
				strategies[i].SetBalance(balancePerStrategy);
			}

			int result = strategies[i].OnInit();

			if (result != INIT_SUCCEEDED) {
				logger.Error(StringFormat(
					"Strategy initialization failed: %s",
					strategies[i].GetName()));
				return INIT_FAILED;
			}
		}

		return INIT_SUCCEEDED;
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
		if (CheckPointer(marketSnapshotsReporter) == POINTER_DYNAMIC) {
			delete marketSnapshotsReporter;
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			if (CheckPointer(strategies[i]) != POINTER_DYNAMIC) {
				continue;
			}

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

		RegisterEntities();

		if (monitorSeedReporter != NULL) {
			monitorSeedReporter.RegisterAsset(symbol);

			for (int i = 0; i < strategyCount; i++) {
				if (strategies[i].IsPassive()) {
					continue;
				}

				monitorSeedReporter.RegisterStrategy(
					strategies[i].GetName(),
					symbol,
					strategies[i].GetPrefix(),
					strategies[i].GetMagicNumber()
				);
			}
		}

		int initResult = initializeStrategies(strategyCount);

		if (initResult != INIT_SUCCEEDED) {
			return initResult;
		}

		if (EnableMarketHistoryReport) {
			string marketReportName = StringFormat("%s_MARKET_Snapshots", symbol);
			marketSnapshotsReporter = new SRReportOfMarketSnapshots(symbol, marketReportName);
		}

		logger.Info(StringFormat(
			"%s initialized | symbol: %s | strategies: %d | weight: %.4f | balance: %.2f",
			name,
			symbol,
			strategyCount,
			weight,
			balance
		));

		remoteOrderManager.Initialize(symbol, strategies);

		SyncToMonitor(GetSnapshotEvent(SNAPSHOT_ON_INIT));
		SendHeartbeats();

		return INIT_SUCCEEDED;
	}

	virtual int OnTesterInit() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTesterInit();
		}

		return INIT_SUCCEEDED;
	}

	virtual void OnTimer() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTimer();
		}

		remoteOrderManager.ProcessEvents();
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
		SendHeartbeats();

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartHour();
		}
	}

	virtual void OnStartDay() {
		if (CheckPointer(marketSnapshotsReporter) != POINTER_INVALID) {
			marketSnapshotsReporter.AddSnapshot(BuildMarketSnapshot());
		}

		if (monitorSeedReporter != NULL) {
			CollectMonitorSeedSnapshots(SNAPSHOT_ON_END_DAY);
		}

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

		remoteOrderManager.OnOpenOrder(order);
	}

	virtual void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (order.GetSource() == strategies[i].GetPrefix()) {
				strategies[i].OnCloseOrder(order, reason);
				break;
			}
		}

		remoteOrderManager.OnCloseOrder(order, reason);
	}

	virtual void OnEnd() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnEnd();
		}
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnDeinit();
		}
	}

	bool HandleOrderCancellation(ulong orderId) {
		int strategyIndex = -1;
		int orderIndex = -1;

		if (!FindOrderByOrderId(orderId, strategyIndex, orderIndex)) {
			return false;
		}

		SEOrderBook *book = strategies[strategyIndex].GetOrderBook();
		EOrder *order = book.GetOrderAtIndex(orderIndex);

		if (order == NULL) {
			return false;
		}

		if (order.GetStatus() != ORDER_STATUS_CLOSING &&
		    order.GetStatus() != ORDER_STATUS_PENDING) {
			return false;
		}

		book.CancelOrder(order);
		remoteOrderManager.OnCancelOrder(order);

		return true;
	}

	bool HandleDealOpen(ulong orderId, ulong dealId, double dealPrice) {
		int strategyIndex = -1;
		int orderIndex = -1;

		if (!FindOrderByOrderId(orderId, strategyIndex, orderIndex)) {
			return false;
		}

		SEOrderBook *book = strategies[strategyIndex].GetOrderBook();
		EOrder *order = book.GetOrderAtIndex(orderIndex);

		if (order == NULL) {
			return false;
		}

		if (order.GetStatus() == ORDER_STATUS_CANCELLED) {
			ulong positionId = HistoryDealGetInteger(dealId, DEAL_POSITION_ID);

			logger.Warning(StringFormat(
				"Rejected fill for cancelled order orderId=%llu, closing orphan positionId=%llu",
				orderId,
				positionId
			));

			if (positionId > 0) {
				book.ForceClosePosition(positionId);
			}

			return true;
		}

		if (order.GetStatus() != ORDER_STATUS_OPEN) {
			MqlTradeResult openResult;
			ZeroMemory(openResult);
			openResult.deal = dealId;
			openResult.order = orderId;
			openResult.price = dealPrice;
			openResult.retcode = TRADE_RETCODE_DONE;
			book.OnOpenOrder(order, openResult);
		}

		strategies[strategyIndex].OnOpenOrder(order);
		remoteOrderManager.OnOpenOrder(order);

		return true;
	}

	bool HandleDealClose(
		ulong positionId,
		SDateTime &dealTime,
		double dealPrice,
		double netProfit,
		double dealProfit,
		double dealCommission,
		double dealSwap,
		ENUM_DEAL_REASON reason
	) {
		int strategyIndex = -1;
		int orderIndex = -1;

		if (!FindOrderByPositionId(positionId, strategyIndex, orderIndex)) {
			return false;
		}

		SEOrderBook *book = strategies[strategyIndex].GetOrderBook();
		EOrder *order = book.GetOrderAtIndex(orderIndex);

		if (order == NULL) {
			return false;
		}

		order.SetGrossProfit(dealProfit);
		order.SetCommission(dealCommission);
		order.SetSwap(dealSwap);
		book.OnCloseOrder(order, dealTime, dealPrice, netProfit, reason);
		strategies[strategyIndex].OnCloseOrder(order, reason);
		remoteOrderManager.OnCloseOrder(order, reason);

		logger.Info(StringFormat(
			"Order closed with positionId=%llu, profit=%.2f",
			positionId,
			netProfit
		));

		return true;
	}

	bool HasMagicNumber(ulong magic) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (strategies[i].GetMagicNumber() == magic) {
				return true;
			}
		}

		return false;
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

			if (strategyQuality == 0) {
				return 0;
			}

			quality = MathPow(
				quality * strategyQuality,
				0.5
			);
		}

		return quality;
	}

	void ExportMarketSnapshots() {
		if (CheckPointer(marketSnapshotsReporter) == POINTER_INVALID) {
			return;
		}

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
			SEOrderBook *book = strategies[i].GetOrderBook();
			int idx = book.FindOrderIndexById(id);

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
			SEOrderBook *book = strategies[i].GetOrderBook();
			int idx = book.FindOrderIndexByOrderId(orderId);

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
			SEOrderBook *book = strategies[i].GetOrderBook();
			int idx = book.FindOrderIndexByPositionId(positionId);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	void ForceEndStatistics() {
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
			if (strategies[i].GetPrefix() == strategyPrefix) {
				return strategies[i];
			}
		}

		return NULL;
	}

	SEStrategy * GetStrategyAtIndex(int index) {
		if (index < 0 || index >= ArraySize(strategies)) {
			return NULL;
		}

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

	void SetName(string newName) {
		name = newName;
	}

	void SetSymbol(string newSymbol) {
		symbol = newSymbol;
	}

	void SetWeight(double newWeight) {
		weight = newWeight;
	}

	void RegisterEntities() {
		if (!horizonMonitor.IsEnabled() && !horizonGateway.IsEnabled()) {
			return;
		}

		horizonMonitor.UpsertAsset(symbol);
		horizonGateway.UpsertAsset(symbol);

		for (int i = 0; i < ArraySize(strategies); i++) {
			horizonMonitor.UpsertStrategy(
				strategies[i].GetName(),
				strategies[i].GetSymbol(),
				strategies[i].GetPrefix(),
				strategies[i].GetMagicNumber()
			);

			horizonGateway.UpsertStrategy(
				strategies[i].GetName(),
				strategies[i].GetSymbol(),
				strategies[i].GetPrefix(),
				strategies[i].GetMagicNumber()
			);
		}
	}

	void SyncToMonitor(string event) {
		if (!horizonMonitor.IsEnabled()) {
			return;
		}

		string assetUuid = horizonMonitor.GetAssetUuid(symbol);
		horizonMonitor.UpsertAssetMetadata(assetUuid, symbol);

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].SyncOrders();
			strategies[i].SyncSnapshot(event);
		}

		StoreAssetSnapshot(assetUuid, event);
	}

	void SendHeartbeats() {
		if (!horizonMonitor.IsEnabled()) {
			return;
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			horizonMonitor.StoreHeartbeat(strategies[i].GetMagicNumber());
		}
	}

	void StoreAssetSnapshot(string assetUuid, string event) {
		if (assetUuid == "") {
			return;
		}

		double floatingPnl = 0;
		double realizedPnl = 0;

		for (int i = 0; i < ArraySize(strategies); i++) {
			SEOrderBook *book = strategies[i].GetOrderBook();

			for (int j = 0; j < book.GetOrdersCount(); j++) {
				EOrder *order = book.GetOrderAtIndex(j);
				if (order != NULL && order.GetStatus() == ORDER_STATUS_OPEN) {
					floatingPnl += book.GetFloatingProfitAndLoss(order);
				}
			}

			SEStatistics *stats = strategies[i].GetStatistics();
			if (stats != NULL) {
				realizedPnl += stats.GetClosedNav() - stats.GetInitialBalance();
			}
		}

		double equity = balance + floatingPnl;
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		string profitCurrency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
		double usdRate = GetAssetRate(profitCurrency);

		horizonMonitor.StoreAssetSnapshot(assetUuid, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate, event);
	}

	void CollectMonitorSeedSnapshots(ENUM_SNAPSHOT_EVENT event) {
		double totalFloatingPnl = 0;
		double totalRealizedPnl = 0;

		for (int i = 0; i < ArraySize(strategies); i++) {
			if (strategies[i].IsPassive()) {
				continue;
			}

			collectStrategySeedSnapshot(strategies[i], event, totalFloatingPnl, totalRealizedPnl);
		}

		collectAssetSeedSnapshot(totalFloatingPnl, totalRealizedPnl, event);
	}

	void collectStrategySeedSnapshot(SEStrategy *strategy, ENUM_SNAPSHOT_EVENT event, double &totalFloatingPnl, double &totalRealizedPnl) {
		double strategyFloatingPnl = 0;
		SEOrderBook *book = strategy.GetOrderBook();

		for (int j = 0; j < book.GetOrdersCount(); j++) {
			EOrder *order = book.GetOrderAtIndex(j);
			if (order != NULL && order.GetStatus() == ORDER_STATUS_OPEN) {
				strategyFloatingPnl += book.GetFloatingProfitAndLoss(order);
			}
		}

		SEStatistics *stats = strategy.GetStatistics();
		double strategyBalance = strategy.GetBalance();
		double strategyRealizedPnl = (stats != NULL) ? stats.GetClosedNav() - stats.GetInitialBalance() : 0.0;
		double strategyEquity = strategyBalance + strategyFloatingPnl;

		monitorSeedReporter.AddStrategySnapshot(
			strategy.GetMagicNumber(),
			strategyBalance,
			strategyEquity,
			strategyFloatingPnl,
			strategyRealizedPnl,
			event,
			dtime.Timestamp()
		);

		totalFloatingPnl += strategyFloatingPnl;
		totalRealizedPnl += strategyRealizedPnl;
	}

	void collectAssetSeedSnapshot(double totalFloatingPnl, double totalRealizedPnl, ENUM_SNAPSHOT_EVENT event) {
		double equity = balance + totalFloatingPnl;
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		string profitCurrency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
		double usdRate = GetAssetRate(profitCurrency);

		monitorSeedReporter.AddAssetSnapshot(symbol, balance, equity, totalFloatingPnl, totalRealizedPnl, bid, ask, usdRate, event, dtime.Timestamp());
	}

	void AggregateSnapshotData(
		double &floatingPnl,
		double &realizedPnl
	) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			SEOrderBook *book = strategies[i].GetOrderBook();

			for (int j = 0; j < book.GetOrdersCount(); j++) {
				EOrder *order = book.GetOrderAtIndex(j);
				if (order != NULL && order.GetStatus() == ORDER_STATUS_OPEN) {
					floatingPnl += book.GetFloatingProfitAndLoss(order);
				}
			}

			SEStatistics *stats = strategies[i].GetStatistics();
			if (stats != NULL) {
				realizedPnl += stats.GetClosedNav() - stats.GetInitialBalance();
			}
		}
	}
};

#endif
