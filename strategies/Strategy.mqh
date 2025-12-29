#ifndef __SE_STRATEGY_MQH__
#define __SE_STRATEGY_MQH__

class SEAsset;

#include "../enums/EOrderStatuses.mqh"
#include "../enums/ETradingModes.mqh"
#include "../structs/SSOrderHistory.mqh"
#include "../structs/SSStatisticsSnapshot.mqh"
#include "../structs/SQualityThresholds.mqh"

#include "../interfaces/IStrategy.mqh"
#include "../services/SELogger/SELogger.mqh"
#include "../services/SEDateTime/SEDateTime.mqh"
#include "../entities/EOrder.mqh"
#include "../services/SEStatistics/SEStatistics.mqh"
#include "../services/SELotSize/SELotSize.mqh"
#include "../helpers/HIsMarketClosed.mqh"
#include "../structs/SQueuedOrder.mqh"

extern SEDateTime dtime;
extern EOrder orders[];
extern SQueuedOrder queuedOrders[];

class SEStrategy:
public IStrategy {
private:
	double weight;
	double balance;
	EOrder openOrders[];

	SEAsset *asset;
	SEStatistics *statistics;
	SELotSize *lotSize;

	void AddToOpenOrders(EOrder &order) {
		ArrayResize(openOrders, ArraySize(openOrders) + 1);
		openOrders[ArraySize(openOrders) - 1] = order;
	}

	void FilterOrders(
		EOrder& sourceOrders[],
		EOrder& resultOrders[],
		ENUM_ORDER_TYPE side,
		ENUM_ORDER_STATUSES status,
		ENUM_ORDER_STATUSES defaultStatus1,
		ENUM_ORDER_STATUSES defaultStatus2 = -1) {
		ArrayResize(resultOrders, 0);

		for (int i = 0; i < ArraySize(sourceOrders); i++) {
			if (sourceOrders[i].GetSource() != prefix)
				continue;

			if (sourceOrders[i].GetSymbol() != symbol)
				continue;

			bool isSideMatch = (side == -1) || (sourceOrders[i].GetSide() == side);
			bool isStatusMatch = false;

			if (status == -1) {
				isStatusMatch = (sourceOrders[i].GetStatus() == defaultStatus1);
				if (defaultStatus2 != -1)
					isStatusMatch = isStatusMatch || (sourceOrders[i].GetStatus() == defaultStatus2);
			} else {
				isStatusMatch = (sourceOrders[i].GetStatus() == status);
			}

			if (isSideMatch && isStatusMatch) {
				ArrayResize(resultOrders, ArraySize(resultOrders) + 1);
				resultOrders[ArraySize(resultOrders) - 1] = sourceOrders[i];
			}
		}

		for (int i = 0; i < ArraySize(queuedOrders); i++) {
			if (queuedOrders[i].action != QUEUE_ACTION_OPEN)
				continue;

			if (queuedOrders[i].order.GetSource() != prefix)
				continue;

			if (queuedOrders[i].order.GetSymbol() != symbol)
				continue;

			bool isSideMatch = (side == -1) || (queuedOrders[i].order.GetSide() == side);

			if (isSideMatch) {
				ArrayResize(resultOrders, ArraySize(resultOrders) + 1);
				resultOrders[ArraySize(resultOrders) - 1] = *queuedOrders[i].order;
			}
		}
	}

	void RemoveFromOpenOrders(EOrder &closedOrder) {
		for (int i = 0; i < ArraySize(openOrders); i++) {
			if (openOrders[i].GetId() == closedOrder.GetId()) {
				for (int j = i; j < ArraySize(openOrders) - 1; j++)
					openOrders[j] = openOrders[j + 1];

				ArrayResize(openOrders, ArraySize(openOrders) - 1);
				break;
			}
		}
	}

	bool ValidateTradingMode(ENUM_ORDER_TYPE side) {
		if (tradingMode == TRADING_MODE_BUY_ONLY && side == ORDER_TYPE_SELL) {
			logger.warning("Order blocked: Trading mode is BUY_ONLY, cannot open SELL order");
			return false;
		}

		if (tradingMode == TRADING_MODE_SELL_ONLY && side == ORDER_TYPE_BUY) {
			logger.warning("Order blocked: Trading mode is SELL_ONLY, cannot open BUY order");
			return false;
		}

		return true;
	}

protected:
	SELogger logger;

	string name;
	string symbol;
	string prefix;
	ulong strategyMagicNumber;
	ENUM_TRADING_MODES tradingMode;

public:
	virtual int OnInit() {
		if (name == "") {
			logger.error("Name not defined for strategy");
			return INIT_FAILED;
		}

		if (symbol == "") {
			logger.error("Symbol not defined for strategy: " + name);
			return INIT_FAILED;
		}

		if (prefix == "") {
			logger.error("Prefix not defined for strategy: " + name);
			return INIT_FAILED;
		}

		if (strategyMagicNumber == 0) {
			logger.error("Magic number not defined for strategy: " + name);
			return INIT_FAILED;
		}

		if (balance <= 0) {
			logger.error("Balance not defined for strategy: " + name);
			return INIT_FAILED;
		}

		if (!SymbolSelect(symbol, true)) {
			logger.error(StringFormat("Symbol '%s' does not exist or cannot be selected", symbol));
			return INIT_FAILED;
		}

		logger.SetPrefix(name);
		SQualityThresholds thresholds;
		statistics = new SEStatistics(symbol, name, prefix, balance);
		lotSize = new SELotSize(symbol);

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
		statistics.OnStartDay();
	}

	virtual void OnStartWeek() {
		statistics.OnStartWeek();
	}

	virtual void OnStartMonth() {
		statistics.OnStartMonth();
	}

	virtual void OnOpenOrder(EOrder& order) {
		AddToOpenOrders(order);
		statistics.OnOpenOrder(order);
	}

	virtual void OnCloseOrder(EOrder& order, ENUM_DEAL_REASON reason) {
		RemoveFromOpenOrders(order);
		statistics.OnCloseOrder(order, reason);
	}

	virtual void OnEndWeek() {
	}

	virtual void OnDeinit() {
	}

	virtual ~SEStrategy() {
		if (CheckPointer(statistics) == POINTER_DYNAMIC)
			delete statistics;

		if (CheckPointer(lotSize) == POINTER_DYNAMIC)
			delete lotSize;
	}

	EOrder * OpenNewOrder(
		ENUM_ORDER_TYPE side,
		double openAtPrice,
		double volume,
		bool isMarketOrder = false,
		bool allowQueueing = false,
		double takeProfit = 0,
		double stopLoss = 0
		) {
		bool isMarketCurrentlyClosed = isMarketClosed(symbol);

		if (isMarketCurrentlyClosed && !allowQueueing) {
			logger.warning("Order blocked: Market is closed");
			return NULL;
		}

		if (!ValidateTradingMode(side))
			return NULL;

		EOrder *order = new EOrder(strategyMagicNumber, symbol);

		double currentPrice = (side == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

		order.SetStatus(ORDER_STATUS_PENDING);
		order.SetSource(prefix);
		order.SetSide(side);
		order.SetVolume(volume);
		order.SetSignalPrice(currentPrice);
		order.SetOpenAtPrice(openAtPrice);
		order.SetSignalAt(dtime.Now());

		order.SetIsMarketOrder(isMarketOrder);
		order.SetAllowQueueing(allowQueueing);

		if (stopLoss > 0)
			order.SetStopLoss(stopLoss);

		if (takeProfit > 0)
			order.SetTakeProfit(takeProfit);

		order.GetId();

		if (isMarketCurrentlyClosed) {
			int size = ArraySize(queuedOrders);
			ArrayResize(queuedOrders, size + 1);

			queuedOrders[size].action = QUEUE_ACTION_OPEN;
			queuedOrders[size].order = order;

			logger.info("Order queued: Market is closed, will execute when market opens");
		} else {
			ArrayResize(orders, ArraySize(orders) + 1);
			orders[ArraySize(orders) - 1] = *order;
		}

		return order;
	}

	void GetOpenOrders(EOrder& resultOrders[], ENUM_ORDER_TYPE side = -1, ENUM_ORDER_STATUSES status = -1) {
		FilterOrders(orders, resultOrders, side, status, ORDER_STATUS_OPEN, ORDER_STATUS_PENDING);
	}

	double GetLotSizeByCapital() {
		return lotSize.CalculateByCapital(
			EquityAtRiskCompounded ? statistics.GetNav() : statistics.GetInitialBalance()
			);
	}

	double GetLotSizeByVolatility(double atrValue, double equityAtRisk) {
		return lotSize.CalculateByVolatility(
			EquityAtRiskCompounded ? statistics.GetNav() : statistics.GetInitialBalance(),
			atrValue,
			equityAtRisk
			);
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

	string GetObjectName(string objectName) {
		string result = GetSymbol() + "_" + GetPrefix() + "_" + GetName() + "_" + objectName + "_" + IntegerToString(GetMagicNumber());
		StringToUpper(result);
		return result;
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
