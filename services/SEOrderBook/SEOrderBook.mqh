#ifndef __SE_ORDER_BOOK_MQH__
#define __SE_ORDER_BOOK_MQH__

#include "../../adapters/ATrade.mqh"

#include "../../constants/COOrder.mqh"

#include "../../entities/EAccount.mqh"
#include "../../entities/EOrder.mqh"

#include "../../enums/EOrderStatuses.mqh"

#include "../../helpers/HIsBuySide.mqh"
#include "helpers/HFilterOrders.mqh"

#include "../../interfaces/IStrategy.mqh"

#include "../../structs/STradingStatus.mqh"

#include "../SEDateTime/SEDateTime.mqh"
#include "../SEDateTime/structs/SDateTime.mqh"

#include "../SELogger/SELogger.mqh"

#include "../SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"

#include "components/OrderFinalizer.mqh"
#include "components/OrderCanceller.mqh"
#include "components/OrderCloser.mqh"
#include "components/OrderModifier.mqh"
#include "components/OrderOpener.mqh"
#include "components/OrderProcessor.mqh"
#include "components/OrderPurger.mqh"
#include "components/OrderRestorer.mqh"

#include "validators/OrderValidator.mqh"

extern SEDateTime dtime;
extern STradingStatus tradingStatus;

class SEOrderBook {
private:
	EAccount account;
	ATrade trade;
	SELogger logger;

	OrderValidator validator;
	OrderFinalizer finalizer;
	OrderOpener opener;
	OrderCloser closer;
	OrderCanceller canceller;
	OrderModifier modifier;
	OrderProcessor processor;
	OrderRestorer restorer;
	OrderPurger purger;

	EOrder orders[];

	IStrategy *listener;
	SRPersistenceOfOrders *orderPersistence;

	string symbol;
	string prefix;
	ulong magicNumber;

public:
	SEOrderBook() {
		logger.SetPrefix("OrderBook");
		orderPersistence = NULL;
		listener = NULL;
	}

	void AddOrder(EOrder &order) {
		if (CheckPointer(orderPersistence) != POINTER_INVALID) {
			order.SetPersistence(orderPersistence);
		}

		int count = ArraySize(orders);
		ArrayResize(orders, count + 1, 16);
		orders[count] = order;
	}

	void CancelAllPendingOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				CloseOrder(orders[i]);
			}
		}
	}

	void CancelOrder(EOrder &order) {
		finalizer.FinalizeCancelled(order);
	}

	void CheckToCancel(EOrder &order) {
		canceller.CheckToCancel(order);
	}

	void CheckToClose(EOrder &order) {
		closer.CheckToClose(order);
	}

	void CheckToOpen(EOrder &order) {
		opener.CheckToOpen(order);
	}

	void CloseAllActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			ENUM_ORDER_STATUSES status = orders[i].GetStatus();

			if (status == ORDER_STATUS_OPEN || status == ORDER_STATUS_PENDING) {
				CloseOrder(orders[i]);
			}
		}
	}

	void CloseOrder(EOrder &order) {
		if (order.GetStatus() == ORDER_STATUS_OPEN) {
			closer.Close(order);
			return;
		}

		if (order.GetStatus() == ORDER_STATUS_PENDING) {
			canceller.Cancel(order);
		}
	}

	bool CloseOrphanPosition(ulong positionId) {
		STradeResult result = trade.Close(positionId);
		return result.severity == TRADE_SEVERITY_SUCCESS;
	}

	void CopyOrders(EOrder &out[]) {
		int count = ArraySize(orders);
		ArrayResize(out, count);

		for (int i = 0; i < count; i++) {
			out[i] = orders[i];
		}
	}

	int FindOrderIndexById(string id) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetId() == id) {
				return i;
			}
		}

		return -1;
	}

	int FindOrderIndexByOrderId(ulong orderId) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetOrderId() == orderId) {
				return i;
			}
		}

		return -1;
	}

	int FindOrderIndexByPositionId(ulong positionId) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetPositionId() == positionId) {
				return i;
			}
		}

		return -1;
	}

	int GetActiveOrderCount() {
		int count = 0;

		for (int i = 0; i < ArraySize(orders); i++) {
			ENUM_ORDER_STATUSES status = orders[i].GetStatus();
			if (status == ORDER_STATUS_OPEN ||
			    status == ORDER_STATUS_PENDING ||
			    status == ORDER_STATUS_CLOSING) {
				count++;
			}
		}

		return count;
	}

	void GetOpenOrders(
		EOrder &resultOrders[],
		ENUM_ORDER_TYPE side = ORDER_TYPE_ANY,
		ENUM_ORDER_STATUSES status = ORDER_STATUS_ANY
	) {
		FilterOrders(
			orders,
			resultOrders,
			side,
			status,
			ORDER_STATUS_OPEN,
			ORDER_STATUS_PENDING
		);
	}

	EOrder * GetOrderAtIndex(int index) {
		if (index < 0 || index >= ArraySize(orders)) {
			return NULL;
		}

		return GetPointer(orders[index]);
	}

	int GetOrdersCount() {
		return ArraySize(orders);
	}

	bool HasActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN ||
			    orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				return true;
			}
		}

		return false;
	}

	bool HasOpenPosition() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN) {
				return true;
			}
		}

		return false;
	}

	bool HasPendingOrder() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				return true;
			}
		}

		return false;
	}

	void Initialize(string orderSymbol, string orderPrefix, ulong orderMagicNumber) {
		symbol = orderSymbol;
		prefix = orderPrefix;
		magicNumber = orderMagicNumber;

		validator.Initialize(symbol, GetPointer(account));
		opener.Initialize(symbol, magicNumber, GetPointer(trade), GetPointer(validator), GetPointer(finalizer));
		closer.Initialize(symbol, GetPointer(trade), GetPointer(finalizer));
		canceller.Initialize(symbol, GetPointer(trade), GetPointer(validator), GetPointer(finalizer));
		modifier.Initialize(symbol, magicNumber, GetPointer(trade));
		processor.Initialize(GetPointer(opener), GetPointer(closer), GetPointer(canceller));
		restorer.Initialize(prefix);
	}

	bool ModifyStopLoss(EOrder &order, double newStopLossPrice) {
		return modifier.ModifyStopLoss(order, newStopLossPrice);
	}

	bool ModifyStopLossAndTakeProfit(EOrder &order, double newStopLossPrice, double newTakeProfitPrice) {
		return modifier.ModifyStopLossAndTakeProfit(order, newStopLossPrice, newTakeProfitPrice);
	}

	bool ModifyTakeProfit(EOrder &order, double newTakeProfitPrice) {
		return modifier.ModifyTakeProfit(order, newTakeProfitPrice);
	}

	void OnCloseOrder(
		EOrder &order,
		const SDateTime &time,
		double price,
		double profits,
		double grossProfit,
		double commission,
		double swap,
		ENUM_DEAL_REASON reason
	) {
		closer.HandleCloseResult(order, time, price, profits, grossProfit, commission, swap, reason);
	}

	void OnDeinit() {
		for (int i = 0; i < ArraySize(orders); i++) {
			orders[i].OnDeinit();
		}

		ArrayResize(orders, 0);
	}

	void OnOpenOrder(EOrder &order, STradeResult &result) {
		opener.HandleOpenResult(order, result);
	}

	void OpenOrder(EOrder &order) {
		opener.Open(order);
	}

	EOrder * PlaceOrder(
		ENUM_ORDER_TYPE side,
		double openAtPrice,
		double volume,
		bool isMarketOrder = true,
		double takeProfit = 0,
		double stopLoss = 0
	) {
		if (tradingStatus.isPaused) {
			logger.Warning(
				LOG_CODE_TRADING_PAUSED,
				StringFormat(
					"trading paused | symbol=%s reason='place order skipped'",
					symbol
			));
			return NULL;
		}

		if (CheckPointer(listener) != POINTER_INVALID && !listener.IsTradable()) {
			logger.Warning(
				LOG_CODE_STRATEGY_NOT_TRADABLE,
				StringFormat(
					"trading paused | symbol=%s reason='strategy not tradable'",
					symbol
			));
			return NULL;
		}

		EOrder order = buildOrder(side, openAtPrice, volume, isMarketOrder, takeProfit, stopLoss);
		AddOrder(order);

		return GetOrderAtIndex(ArraySize(orders) - 1);
	}

	void ProcessOrders() {
		processor.Process(orders);
	}

	void PurgeClosedOrders() {
		purger.Purge(orders);
	}

	int QueryPersistedOrders(SEDbQuery &query, JSON::Object *&results[]) {
		return restorer.QueryOrders(query, results);
	}

	int RestoreOrders(EOrder &reconciledOrders[]) {
		EOrder activeOrders[];
		int totalRestored = restorer.LoadAndSplit(orders, activeOrders, reconciledOrders);

		if (totalRestored == -1) {
			return -1;
		}

		for (int i = 0; i < totalRestored; i++) {
			AddOrder(activeOrders[i]);
		}

		return totalRestored;
	}

	void SetListener(IStrategy *strategyListener) {
		listener = strategyListener;
		finalizer.SetListener(listener);
		opener.SetListener(listener);
		closer.SetListener(listener);
		canceller.SetListener(listener);
	}

	void SetPersistence(SRPersistenceOfOrders *persistence) {
		orderPersistence = persistence;
		finalizer.SetPersistence(orderPersistence);
		restorer.SetPersistence(orderPersistence);
		purger.SetPersistence(orderPersistence);
	}

private:
	EOrder buildOrder(
		ENUM_ORDER_TYPE side,
		double openAtPrice,
		double volume,
		bool isMarketOrder,
		double takeProfit,
		double stopLoss
	) {
		EOrder order(magicNumber, symbol);

		double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
		double currentPrice = IsBuySide(side) ? askPrice : bidPrice;

		order.SetStatus(ORDER_STATUS_PENDING);
		order.SetSource(prefix);
		order.SetSide(side);
		order.SetVolume(volume);
		order.SetSignalPrice(currentPrice);
		order.SetOpenAtPrice(openAtPrice);
		order.SetSignalAt(dtime.Now());
		order.SetIsMarketOrder(isMarketOrder);

		if (stopLoss > 0) {
			order.SetStopLossPrice(stopLoss);
		}

		if (takeProfit > 0) {
			order.SetTakeProfitPrice(takeProfit);
		}

		return order;
	}
};

#endif
