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
#include "../services/SEDateTime/structs/SDateTime.mqh"
#include "../entities/EOrder.mqh"
#include "../services/SEStatistics/SEStatistics.mqh"
#include "../services/SELotSize/SELotSize.mqh"
#include "../helpers/HIsMarketClosed.mqh"

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

	void filterOrders(
		EOrder& resultOrders[],
		ENUM_ORDER_TYPE side,
		ENUM_ORDER_STATUSES status,
		ENUM_ORDER_STATUSES defaultStatus1,
		ENUM_ORDER_STATUSES defaultStatus2 = ORDER_STATUS_ANY) {
		ArrayResize(resultOrders, 0);

		for (int i = 0; i < ArraySize(orders); i++) {
			bool isSideMatch = (side == ORDER_TYPE_ANY) ||
					   (orders[i].GetSide() == side);
			bool isStatusMatch = false;

			if (status == ORDER_STATUS_ANY) {
				isStatusMatch = (orders[i].GetStatus() == defaultStatus1);
				if (defaultStatus2 != ORDER_STATUS_ANY)
					isStatusMatch = isStatusMatch ||
							(orders[i].GetStatus() == defaultStatus2);
			} else {
				isStatusMatch = (orders[i].GetStatus() == status);
			}

			if (isSideMatch && isStatusMatch) {
				ArrayResize(resultOrders, ArraySize(resultOrders) + 1);
				resultOrders[ArraySize(resultOrders) - 1] = orders[i];
			}
		}
	}

	bool validateTradingMode(ENUM_ORDER_TYPE side) {
		if (tradingMode == TRADING_MODE_BUY_ONLY && side == ORDER_TYPE_SELL) {
			logger.warning(
				"Order blocked: Trading mode is BUY_ONLY, cannot open SELL order");
			return false;
		}

		if (tradingMode == TRADING_MODE_SELL_ONLY && side == ORDER_TYPE_BUY) {
			logger.warning(
				"Order blocked: Trading mode is SELL_ONLY, cannot open BUY order");
			return false;
		}

		return true;
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
			logger.error(StringFormat(
					     "Symbol '%s' does not exist or cannot be selected",
					     symbol));
			return INIT_FAILED;
		}

		countOrdersOfToday = 0;
		countOpenOrders = 0;
		countClosedOrders = 0;
		logger.SetPrefix(name);
		statistics = new SEStatistics(symbol, name, prefix, balance);
		lotSize = new SELotSize(symbol);

		initializeDefaultThresholds();

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
		statistics.OnStartDay(orders);
		countOrdersOfToday = 0;
	}

	virtual void OnStartWeek() {
		statistics.OnStartWeek();
	}

	virtual void OnStartMonth() {
		statistics.OnStartMonth();
	}

	virtual void OnOpenOrder(EOrder& order) {
		statistics.OnOpenOrder(order, orders);
	}

	virtual void OnCloseOrder(EOrder& order, ENUM_DEAL_REASON reason) {
		statistics.OnCloseOrder(order, reason, orders);
		countOpenOrders--;
		countClosedOrders++;
	}

	virtual void OnEndWeek() {
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(orders); i++)
			orders[i].OnDeinit();

		ArrayResize(orders, 0);
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
		bool isMarketOrder = true,
		double takeProfit = 0,
		double stopLoss = 0
	) {
		if (!validateTradingMode(side))
			return NULL;

		EOrder *order = new EOrder(strategyMagicNumber, symbol);

		double currentPrice = (side ==
				       ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol,
									  SYMBOL_ASK) :
				      SymbolInfoDouble(symbol, SYMBOL_BID);

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

		ArrayResize(orders, ArraySize(orders) + 1);
		orders[ArraySize(orders) - 1] = *order;

		countOrdersOfToday++;
		countOpenOrders++;

		return order;
	}

	void GetOpenOrders(EOrder& resultOrders[],
			   ENUM_ORDER_TYPE side = ORDER_TYPE_ANY,
			   ENUM_ORDER_STATUSES status = ORDER_STATUS_ANY) {
		filterOrders(resultOrders, side, status, ORDER_STATUS_OPEN,
			     ORDER_STATUS_PENDING);
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
		for (int i = 0; i < ArraySize(orders); i++)
			if (orders[i].GetOrderId() == orderId)
				return i;

		return -1;
	}

	int FindOrderIndexByPositionId(ulong positionId) {
		for (int i = 0; i < ArraySize(orders); i++)
			if (orders[i].GetPositionId() == positionId)
				return i;

		return -1;
	}

	int FindOrderIndexById(string id) {
		for (int i = 0; i < ArraySize(orders); i++)
			if (orders[i].GetId() == id)
				return i;

		return -1;
	}

	void ProcessOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (!orders[i].IsInitialized())
				orders[i].OnInit();

			if (orders[i].GetStatus() == ORDER_STATUS_PENDING)
				orders[i].CheckToOpen();

			if (orders[i].GetStatus() == ORDER_STATUS_OPEN)
				orders[i].CheckToClose();
		}
	}

	void CleanupClosedOrders() {
		EOrder activeOrders[];
		int activeCount = 0;

		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() != ORDER_STATUS_CLOSED &&
			    orders[i].GetStatus() != ORDER_STATUS_CANCELLED) {
				ArrayResize(activeOrders, activeCount + 1);
				activeOrders[activeCount] = orders[i];
				activeCount++;
			} else {
				orders[i].OnDeinit();
			}
		}

		ArrayResize(orders, activeCount);

		for (int i = 0; i < activeCount; i++)
			orders[i] = activeOrders[i];
	}

	void AddOrder(EOrder &order) {
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

	double GetLotSizeByCapital() {
		double nav =
			EquityAtRiskCompounded ? statistics.GetNav() :
			statistics.GetInitialBalance();
		return lotSize.CalculateByCapital(nav * EquityAtRisk / 100.0);
	}

	double GetLotSizeByVolatility(double atrValue, double equityAtRisk) {
		return lotSize.CalculateByVolatility(
			EquityAtRiskCompounded ? statistics.GetNav() :
			statistics.GetInitialBalance(),
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
		string result = GetSymbol() + "_" + GetPrefix() + "_" + GetName() +
				"_" + objectName + "_" +
				IntegerToString(GetMagicNumber());
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
