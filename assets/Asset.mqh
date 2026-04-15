#ifndef __SE_ASSET_MQH__
#define __SE_ASSET_MQH__

#include "../interfaces/IAsset.mqh"

#include "../helpers/HStringToNumber.mqh"
#include "../helpers/HGetAssetRate.mqh"

#include "../enums/ESnapshotEvent.mqh"

#include "../services/SELogger/SELogger.mqh"
#include "../services/SRReportOfMarketSnapshots/SRReportOfMarketSnapshots.mqh"
#include "../services/SRReportOfMonitorSeed/SRReportOfMonitorSeed.mqh"
#include "../services/SRImplementationOfHorizonMonitor/SRImplementationOfHorizonMonitor.mqh"
#include "../services/SRImplementationOfHorizonGateway/SRImplementationOfHorizonGateway.mqh"
#include "../services/SEGateway/SEGateway.mqh"

#include "../entities/EOrder.mqh"

#include "../indicators/INRollingReturn.mqh"
#include "../indicators/INDrawdownFromPeak.mqh"
#include "../indicators/INVolatility.mqh"

#include "../strategies/Strategy.mqh"

extern SEDateTime dtime;
extern SRImplementationOfHorizonMonitor horizonMonitor;
extern SRImplementationOfHorizonGateway horizonGateway;
extern SRReportOfMonitorSeed *monitorSeedReporter;

#include "../constants/COAsset.mqh"

class SEAsset:
public IAsset {
private:
	SELogger logger;
	SRReportOfMarketSnapshots *marketSnapshotsReporter;
	SEGateway gateway;

	string name;
	double weight;
	bool isEnabled;
	double balance;

	SEStrategy *strategies[];

protected:
	string symbol;
	datetime lastM1BarOpen;
	datetime lastH1BarOpen;
	datetime lastD1BarOpen;
	bool m1Primed;
	bool h1Primed;
	bool d1Primed;

public:
	SEAsset() {
		logger.SetPrefix("SEAsset");
		marketSnapshotsReporter = NULL;
		weight = 0;
		isEnabled = false;
		balance = 0;
		lastM1BarOpen = 0;
		lastH1BarOpen = 0;
		lastD1BarOpen = 0;
		m1Primed = false;
		h1Primed = false;
		d1Primed = false;
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

	void AddStrategy(SEStrategy *strategy) {
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

		if (!strategy.IsPassive()) {
			isEnabled = true;
		}
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
					floatingPnl += order.GetFloatingPnL();
				}
			}

			SEStatistics *stats = strategies[i].GetStatistics();
			if (stats != NULL) {
				realizedPnl += stats.GetClosedNav() - stats.GetInitialBalance();
			}
		}
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

	void ExportMarketSnapshots() {
		if (CheckPointer(marketSnapshotsReporter) != POINTER_DYNAMIC) {
			return;
		}

		marketSnapshotsReporter.Export();

		logger.Info(
			LOG_CODE_STATS_EXPORTED,
			StringFormat(
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

	SEStrategy * GetStrategyAtIndex(int index) {
		if (index < 0 || index >= ArraySize(strategies)) {
			return NULL;
		}

		return strategies[index];
	}

	SEStrategy * GetStrategyByPrefix(string strategyPrefix) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (strategies[i].GetPrefix() == strategyPrefix) {
				return strategies[i];
			}
		}

		return NULL;
	}

	int GetStrategyCount() {
		return ArraySize(strategies);
	}

	string GetSymbol() {
		return symbol;
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

		book.OnCloseOrder(order, dealTime, dealPrice, netProfit, dealProfit, dealCommission, dealSwap, reason);
		strategies[strategyIndex].OnCloseOrder(order, reason);
		gateway.OnCloseOrder(order, reason, strategies[strategyIndex].GetStrategyUuid());

		logger.Info(
			LOG_CODE_ORDER_CLOSED,
			StringFormat(
				"Order closed with positionId=%llu, profit=%.2f",
				positionId,
				netProfit
		));

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

			logger.Warning(
				LOG_CODE_ORDER_ORPHAN_CLOSED,
				StringFormat(
					"orphan fill detected | order_ticket=%llu position_id=%llu reason='fill arrived for cancelled order' action='closing orphan'",
					orderId,
					positionId
			));

			if (positionId > 0) {
				book.CloseOrphanPosition(positionId);
			}

			return true;
		}

		if (order.GetStatus() != ORDER_STATUS_OPEN) {
			STradeResult openResult;
			ZeroMemory(openResult);
			openResult.dealId = dealId;
			openResult.orderId = orderId;
			openResult.price = dealPrice;
			openResult.retcode = TRADE_RETCODE_DONE;
			openResult.severity = TRADE_SEVERITY_SUCCESS;
			book.OnOpenOrder(order, openResult);
		}

		strategies[strategyIndex].OnOpenOrder(order);
		gateway.OnOpenOrder(order, strategies[strategyIndex].GetStrategyUuid());

		return true;
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
		gateway.OnCancelOrder(order, strategies[strategyIndex].GetStrategyUuid());

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

	bool IsEnabled() {
		return isEnabled;
	}

	virtual void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		SEStrategy *strategy = GetStrategyByPrefix(order.GetSource());
		string targetStrategyUuid = "";

		if (strategy != NULL) {
			strategy.OnCloseOrder(order, reason);
			targetStrategyUuid = strategy.GetStrategyUuid();
		}

		gateway.OnCloseOrder(order, reason, targetStrategyUuid);
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnDeinit();
		}
	}

	virtual void OnEnd() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnEnd();
		}
	}

	virtual int OnInit() {
		int strategyCount = ArraySize(strategies);

		if (strategyCount == 0) {
			logger.Info(
				LOG_CODE_FRAMEWORK_INIT_SKIPPED,
				StringFormat(
					"Asset skipped (no strategies): %s",
					name
			));

			return INIT_SUCCEEDED;
		}

		if (isEnabled && !RegisterEntities()) {
			return INIT_FAILED;
		}

		int initResult = initializeStrategies(strategyCount);

		if (initResult != INIT_SUCCEEDED) {
			return initResult;
		}

		if (!isEnabled) {
			return INIT_SUCCEEDED;
		}

		registerStrategiesWithMonitorSeed(strategyCount);

		if (EnableMarketHistoryReport) {
			createMarketSnapshotsReporter();
		}

		logger.Info(
			LOG_CODE_FRAMEWORK_INIT_OK,
			StringFormat(
				"%s initialized | symbol: %s | strategies: %d | weight: %.4f | balance: %.2f",
				name,
				symbol,
				strategyCount,
				weight,
				balance
		));

		gateway.Initialize(symbol, strategies);

		SyncToMonitor(SNAPSHOT_ON_INIT);
		SendHeartbeats();

		return INIT_SUCCEEDED;
	}

	virtual void OnOpenOrder(EOrder &order) {
		SEStrategy *strategy = GetStrategyByPrefix(order.GetSource());
		string targetStrategyUuid = "";

		if (strategy != NULL) {
			strategy.OnOpenOrder(order);
			targetStrategyUuid = strategy.GetStrategyUuid();
		}

		gateway.OnOpenOrder(order, targetStrategyUuid);
	}

	virtual void OnStartDay() {
		if (CheckPointer(marketSnapshotsReporter) == POINTER_DYNAMIC) {
			marketSnapshotsReporter.AddSnapshot(buildMarketSnapshot());
		}

		if (monitorSeedReporter != NULL) {
			CollectMonitorSeedSnapshots(SNAPSHOT_ON_END_DAY);
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartDay();
		}
	}

	virtual void OnStartHour() {
		SendHeartbeats();

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartHour();
		}
	}

	virtual void OnStartMinute() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartMinute();
		}
	}

	virtual int OnTesterInit() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTesterInit();
		}

		return INIT_SUCCEEDED;
	}

	virtual void OnTick() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTick();
		}
	}

	virtual void OnTimer() {
		if (ArraySize(strategies) == 0 || !isEnabled) {
			return;
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTimer();
		}

		gateway.ProcessEvents();
	}

	virtual void ProcessBarEvents() {
		datetime m1BarOpen = iTime(symbol, PERIOD_M1, 0);

		if (m1BarOpen > 0 && m1BarOpen != lastM1BarOpen) {
			lastM1BarOpen = m1BarOpen;
			if (m1Primed) {
				OnStartMinute();
			} else {
				m1Primed = true;
			}
		}

		datetime h1BarOpen = iTime(symbol, PERIOD_H1, 0);

		if (h1BarOpen > 0 && h1BarOpen != lastH1BarOpen) {
			lastH1BarOpen = h1BarOpen;
			if (h1Primed) {
				OnStartHour();
			} else {
				h1Primed = true;
			}
		}

		datetime d1BarOpen = iTime(symbol, PERIOD_D1, 0);

		if (d1BarOpen > 0 && d1BarOpen != lastD1BarOpen) {
			lastD1BarOpen = d1BarOpen;
			if (d1Primed) {
				OnStartDay();
			} else {
				d1Primed = true;
			}
		}
	}

	void ProcessOrders() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].ProcessOrders();
		}
	}

	bool RegisterEntities() {
		bool monitorEnabled = horizonMonitor.IsEnabled();
		bool gatewayEnabled = horizonGateway.IsEnabled();

		if (!monitorEnabled && !gatewayEnabled) {
			return true;
		}

		if (monitorEnabled && !registerAssetOnMonitor()) {
			return false;
		}

		if (gatewayEnabled && !registerAssetOnGateway()) {
			return false;
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			if (monitorEnabled && !registerStrategyOnMonitor(strategies[i])) {
				return false;
			}

			if (gatewayEnabled && !registerStrategyOnGateway(strategies[i])) {
				return false;
			}
		}

		return true;
	}

	void RegisterStrategyIf(bool enabled, SEStrategy *strategy) {
		if (!enabled) {
			delete strategy;
			return;
		}

		AddStrategy(strategy);
	}

	void SendHeartbeats() {
		if (!horizonMonitor.IsEnabled()) {
			return;
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			horizonMonitor.StoreHeartbeat(strategies[i].GetMagicNumber());
		}
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

	void SyncToMonitor(ENUM_SNAPSHOT_EVENT event) {
		if (!horizonMonitor.IsEnabled()) {
			return;
		}

		string assetUuid = horizonMonitor.GetAssetUuid(symbol);
		horizonMonitor.UpsertAssetMetadata(assetUuid, symbol);

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].SyncSnapshot(event);
		}

		storeAssetSnapshot(assetUuid, event);
	}

private:
	SSMarketSnapshot buildMarketSnapshot() {
		SSMarketSnapshot snapshot;
		double bid = 0;
		double ask = 0;
		readQuote(bid, ask);

		snapshot.timestamp = dtime.Timestamp();
		snapshot.bid = bid;
		snapshot.ask = ask;
		snapshot.spread = ask - bid;
		snapshot.rollingPerformance = RollingReturn(symbol, PERIOD_D1, ROLLING_PERIOD_DAYS, 0);
		snapshot.rollingDrawdown = DrawdownFromPeak(symbol, PERIOD_D1, ROLLING_PERIOD_DAYS, 0);
		snapshot.rollingVolatility = Volatility(symbol, PERIOD_D1, ROLLING_PERIOD_DAYS, 0);
		return snapshot;
	}

	void collectAssetSeedSnapshot(double totalFloatingPnl, double totalRealizedPnl, ENUM_SNAPSHOT_EVENT event) {
		double equity = balance + totalFloatingPnl;
		double bid = 0;
		double ask = 0;
		double usdRate = 0;
		readMarketContext(bid, ask, usdRate);

		monitorSeedReporter.AddAssetSnapshot(symbol, balance, equity, totalFloatingPnl, totalRealizedPnl, bid, ask, usdRate, event, dtime.Timestamp());
	}

	void collectStrategySeedSnapshot(SEStrategy *strategy, ENUM_SNAPSHOT_EVENT event, double &totalFloatingPnl, double &totalRealizedPnl) {
		double strategyFloatingPnl = 0;
		SEOrderBook *book = strategy.GetOrderBook();

		for (int j = 0; j < book.GetOrdersCount(); j++) {
			EOrder *order = book.GetOrderAtIndex(j);
			if (order != NULL && order.GetStatus() == ORDER_STATUS_OPEN) {
				strategyFloatingPnl += order.GetFloatingPnL();
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

	void createMarketSnapshotsReporter() {
		string marketReportName = StringFormat("%s_MARKET_Snapshots", symbol);
		marketSnapshotsReporter = new SRReportOfMarketSnapshots(symbol, marketReportName);
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
				logger.Error(
					LOG_CODE_FRAMEWORK_INIT_FAILED,
					StringFormat(
						"strategy init failed | strategy=%s",
						strategies[i].GetName()
				));
				return INIT_FAILED;
			}
		}

		return INIT_SUCCEEDED;
	}

	void readMarketContext(double &bid, double &ask, double &usdRate) {
		readQuote(bid, ask);
		string profitCurrency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
		usdRate = GetAssetRate(profitCurrency);
	}

	void readQuote(double &bid, double &ask) {
		bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
	}

	bool registerAssetOnGateway() {
		string gatewayAssetUuid = horizonGateway.UpsertAsset(symbol);

		if (gatewayAssetUuid == "") {
			logger.Error(
				LOG_CODE_CONFIG_MISSING_DEPENDENCY,
				StringFormat(
					"asset uuid missing | symbol=%s reason='horizonGateway.UpsertAsset returned empty uuid'",
					symbol
			));
			return false;
		}

		return true;
	}

	bool registerAssetOnMonitor() {
		string monitorAssetUuid = horizonMonitor.UpsertAsset(symbol);

		if (monitorAssetUuid == "") {
			logger.Error(
				LOG_CODE_CONFIG_MISSING_DEPENDENCY,
				StringFormat(
					"asset uuid missing | symbol=%s reason='horizonMonitor.UpsertAsset returned empty uuid'",
					symbol
			));
			return false;
		}

		return true;
	}

	void registerStrategiesWithMonitorSeed(int strategyCount) {
		if (monitorSeedReporter == NULL) {
			return;
		}

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

	bool registerStrategyOnGateway(SEStrategy *strategy) {
		string gatewayStrategyUuid = horizonGateway.UpsertStrategy(
			strategy.GetName(),
			strategy.GetSymbol(),
			strategy.GetPrefix(),
			strategy.GetMagicNumber()
		);

		if (gatewayStrategyUuid == "") {
			logger.Error(
				LOG_CODE_CONFIG_MISSING_DEPENDENCY,
				StringFormat(
					"strategy uuid missing | strategy=%s magic=%llu reason='horizonGateway.UpsertStrategy returned empty uuid'",
					strategy.GetName(),
					strategy.GetMagicNumber()
			));
			return false;
		}

		strategy.SetStrategyUuid(gatewayStrategyUuid);
		return true;
	}

	bool registerStrategyOnMonitor(SEStrategy *strategy) {
		string monitorStrategyUuid = horizonMonitor.UpsertStrategy(
			strategy.GetName(),
			strategy.GetSymbol(),
			strategy.GetPrefix(),
			strategy.GetMagicNumber()
		);

		if (monitorStrategyUuid == "") {
			logger.Error(
				LOG_CODE_CONFIG_MISSING_DEPENDENCY,
				StringFormat(
					"strategy uuid missing | strategy=%s magic=%llu reason='horizonMonitor.UpsertStrategy returned empty uuid'",
					strategy.GetName(),
					strategy.GetMagicNumber()
			));
			return false;
		}

		return true;
	}

	void storeAssetSnapshot(string assetUuid, ENUM_SNAPSHOT_EVENT event) {
		if (assetUuid == "") {
			return;
		}

		double floatingPnl = 0;
		double realizedPnl = 0;
		AggregateSnapshotData(floatingPnl, realizedPnl);

		double bid = 0;
		double ask = 0;
		double usdRate = 0;
		readMarketContext(bid, ask, usdRate);

		double equity = balance + floatingPnl;

		horizonMonitor.StoreAssetSnapshot(assetUuid, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate, event);
	}
};

#endif
