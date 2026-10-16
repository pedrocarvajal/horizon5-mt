#ifndef __SE_ASSET_MQH__
#define __SE_ASSET_MQH__

#include "../interfaces/IAsset.mqh"

#include "../helpers/HStringToNumber.mqh"

#include "../services/SELogger/SELogger.mqh"
#include "../services/SRReportOfMarketSnapshots/SRReportOfMarketSnapshots.mqh"

#include "../entities/EOrder.mqh"
#include "../entities/ETradingStatus.mqh"

#include "../indicators/INRollingReturn.mqh"
#include "../indicators/INDrawdownFromPeak.mqh"
#include "../indicators/INVolatility.mqh"

#include "../strategies/Strategy.mqh"

extern SEDateTime dtime;

#include "../constants/COAsset.mqh"

class SEAsset:
public IAsset {
private:
	SELogger logger;
	SRReportOfMarketSnapshots *marketSnapshotsReporter;
	ETradingStatus tradingStatus;

	string name;
	double weight;
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
		strategy.SetTradingStatus(GetPointer(tradingStatus));
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

		book.OnCloseOrder(order, dealTime, dealPrice, netProfit, reason);
		strategies[strategyIndex].OnCloseOrder(order, reason);

		if (isManualDealReason(reason)) {
			pauseTrading("manual close detected", strategies[strategyIndex].GetName());
		}

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

		return true;
	}

	bool HandleOrderCancellation(ulong orderId, ENUM_ORDER_STATE orderState) {
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

		bool isCancelledOutsideExpert = orderState == ORDER_STATE_CANCELED && order.GetStatus() == ORDER_STATUS_PENDING;
		book.CancelOrder(order);

		if (isCancelledOutsideExpert) {
			pauseTrading("manual cancel detected", strategies[strategyIndex].GetName());
		}

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
		return ArraySize(strategies) > 0;
	}

	virtual void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		SEStrategy *strategy = GetStrategyByPrefix(order.GetSource());

		if (strategy != NULL) {
			strategy.OnCloseOrder(order, reason);
		}
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

		int initResult = initializeStrategies(strategyCount);

		if (initResult != INIT_SUCCEEDED) {
			return initResult;
		}

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

		return INIT_SUCCEEDED;
	}

	virtual void OnOpenOrder(EOrder &order) {
		SEStrategy *strategy = GetStrategyByPrefix(order.GetSource());

		if (strategy != NULL) {
			strategy.OnOpenOrder(order);
		}
	}

	virtual void OnStartDay() {
		if (CheckPointer(marketSnapshotsReporter) == POINTER_DYNAMIC) {
			marketSnapshotsReporter.AddSnapshot(buildMarketSnapshot());
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnStartDay();
		}
	}

	virtual void OnStartHour() {
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
		if (!IsEnabled()) {
			return;
		}

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].OnTimer();
		}
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

	void RegisterStrategyIf(bool enabled, SEStrategy *strategy) {
		if (!enabled) {
			delete strategy;
			return;
		}

		AddStrategy(strategy);
	}

	void ResumeTrading() {
		if (!tradingStatus.IsPaused()) {
			return;
		}

		tradingStatus.Resume();
		logger.Info(
			LOG_CODE_TRADING_PAUSED,
			StringFormat(
				"trading resumed | symbol=%s reason='new day started'",
				symbol
		));
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

	void createMarketSnapshotsReporter() {
		string marketReportName = StringFormat("%s_MARKET_Snapshots", symbol);
		marketSnapshotsReporter = new SRReportOfMarketSnapshots(symbol, marketReportName);
	}

	int initializeStrategies(int strategyCount) {
		double balancePerStrategy = balance / strategyCount;

		for (int i = 0; i < strategyCount; i++) {
			strategies[i].SetBalance(balancePerStrategy);

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

	bool isManualDealReason(ENUM_DEAL_REASON reason) {
		return reason == DEAL_REASON_CLIENT || reason == DEAL_REASON_MOBILE || reason == DEAL_REASON_WEB;
	}

	void pauseTrading(string reason, string strategyName) {
		if (tradingStatus.IsPaused()) {
			return;
		}

		tradingStatus.Pause();
		logger.Warning(
			LOG_CODE_TRADING_PAUSED,
			StringFormat(
				"trading paused | symbol=%s strategy=%s reason='%s' until='next day'",
				symbol,
				strategyName,
				reason
		));
	}

	void readQuote(double &bid, double &ask) {
		bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
	}
};

#endif
