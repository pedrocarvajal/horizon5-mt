#ifndef __SE_ORDER_BOOK_MQH__
#define __SE_ORDER_BOOK_MQH__

#include "../../constants/time.mqh"

#include "../../enums/EOrderStatuses.mqh"
#include "../../structs/STradingStatus.mqh"

#include "../../helpers/HIsMarketClosed.mqh"

#include "../../services/SELogger/SELogger.mqh"
#include "../../services/SEDateTime/SEDateTime.mqh"
#include "../../services/SEDateTime/structs/SDateTime.mqh"
#include "../../services/SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"

#include "../../entities/EOrder.mqh"
#include "../../adapters/ATrade.mqh"

#define ORDER_TYPE_ANY    -1
#define ORDER_STATUS_ANY  -1
#define MAX_RETRY_COUNT   3

extern SEDateTime dtime;
extern STradingStatus tradingStatus;

class SEStrategy;

class SEOrderBook {
public:
	EOrder orders[];

private:
	SELogger logger;
	ATrade trade;

	int openOrderCount;
	int closedOrderCount;
	int todayOrderCount;

	string symbol;
	string prefix;
	ulong magicNumber;

	SRPersistenceOfOrders *orderPersistence;
	SEStrategy *listener;

public:
	SEOrderBook() {
		logger.SetPrefix("OrderBook");
		openOrderCount = 0;
		closedOrderCount = 0;
		todayOrderCount = 0;
		orderPersistence = NULL;
		listener = NULL;
	}

	void Initialize(string orderSymbol, string orderPrefix, ulong orderMagicNumber) {
		symbol = orderSymbol;
		prefix = orderPrefix;
		magicNumber = orderMagicNumber;
	}

	void SetListener(SEStrategy *strategyListener) {
		listener = strategyListener;
	}

	void SetPersistence(SRPersistenceOfOrders *persistence) {
		orderPersistence = persistence;
	}

	void AddOrder(EOrder &order) {
		if (CheckPointer(orderPersistence) != POINTER_INVALID) {
			order.SetPersistence(orderPersistence);
		}

		int count = ArraySize(orders);
		ArrayResize(orders, count + 1, 16);
		orders[count] = order;
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
			return NULL;
		}

		EOrder order(magicNumber, symbol);
		double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
		double currentPrice = (side == ORDER_TYPE_BUY || side == ORDER_TYPE_BUY_STOP || side == ORDER_TYPE_BUY_LIMIT)
			? askPrice : bidPrice;

		order.SetStatus(ORDER_STATUS_PENDING);
		order.SetSource(prefix);
		order.SetSide(side);
		order.SetVolume(volume);
		order.SetSignalPrice(currentPrice);
		order.SetOpenAtPrice(openAtPrice);
		SDateTime signalTime = dtime.Now();
		order.SetSignalAt(signalTime);
		order.SetIsMarketOrder(isMarketOrder);

		if (stopLoss > 0) {
			order.stopLossPrice = stopLoss;
		}

		if (takeProfit > 0) {
			order.takeProfitPrice = takeProfit;
		}

		AddOrder(order);
		todayOrderCount++;
		openOrderCount++;

		return GetOrderAtIndex(GetOrdersCount() - 1);
	}

	void ProcessOrders() {
		if (openOrderCount == 0) {
			return;
		}

		for (int i = 0; i < ArraySize(orders); i++) {
			if (!orders[i].IsInitialized()) {
				orders[i].OnInit();
			}

			ENUM_ORDER_STATUSES statusBefore = orders[i].GetStatus();

			if (statusBefore == ORDER_STATUS_PENDING) {
				if (orders[i].pendingToClose) {
					CheckToCancel(orders[i]);

					if (orders[i].GetStatus() == ORDER_STATUS_CANCELLED) {
						NotifyOrderCancelled(orders[i]);
					}
				} else if (tradingStatus.isPaused) {
					CloseOrder(orders[i]);

					if (orders[i].GetStatus() == ORDER_STATUS_CANCELLED) {
						NotifyOrderCancelled(orders[i]);
					}
				} else {
					CheckToOpen(orders[i]);

					if (orders[i].GetStatus() == ORDER_STATUS_CANCELLED) {
						NotifyOrderCancelled(orders[i]);
					}
				}
			}

			if (statusBefore == ORDER_STATUS_OPEN) {
				CheckToClose(orders[i]);
			}
		}
	}

	void CloseAllActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_OPEN) {
				CloseOrder(orders[i]);
			} else if (orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				CloseOrder(orders[i]);

				if (orders[i].GetStatus() == ORDER_STATUS_CANCELLED) {
					NotifyOrderCancelled(orders[i]);
				}
			}
		}
	}

	void CancelAllPendingOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				CloseOrder(orders[i]);

				if (orders[i].GetStatus() == ORDER_STATUS_CANCELLED) {
					NotifyOrderCancelled(orders[i]);
				}
			}
		}
	}

	void ExpireAllPendingOrders() {
		CancelAllPendingOrders();
	}

	bool ForceClosePosition(ulong positionId) {
		return trade.Close(positionId);
	}

	void CheckToOpen(EOrder &order) {
		if (!order.pendingToOpen || order.isProcessed) {
			return;
		}

		datetime currentTime = dtime.Timestamp();

		if (order.retryAfter > 0 && currentTime < order.retryAfter) {
			return;
		}

		if (order.retryCount >= MAX_RETRY_COUNT) {
			logger.Warning(StringFormat("[%s] Max retry count reached, cancelling order", order.GetId()));
			CancelOrder(order);
			return;
		}

		logger.Info(StringFormat("[%s] Opening order, id: %s", order.GetId(), order.GetId()));
		OpenOrder(order);
	}

	void CheckToCancel(EOrder &order) {
		datetime currentTime = dtime.Timestamp();

		if (order.retryAfter > 0 && currentTime < order.retryAfter) {
			return;
		}

		if (order.GetOrderId() > 0 && !OrderSelect(order.GetOrderId())) {
			CancelOrder(order);
			return;
		}

		CloseOrder(order);
	}

	void CheckToClose(EOrder &order) {
		if (!order.pendingToClose) {
			return;
		}

		datetime currentTime = dtime.Timestamp();

		if (order.retryAfter > 0 && currentTime < order.retryAfter) {
			return;
		}

		if (order.retryCount >= MAX_RETRY_COUNT) {
			logger.Warning(StringFormat("[%s] Max retry count reached for close, giving up", order.GetId()));
			order.pendingToClose = false;
			order.retryCount = 0;
			return;
		}

		CloseOrder(order);
	}

	void OpenOrder(EOrder &order) {
		SMarketStatus marketStatus = GetMarketStatus(symbol);

		if (marketStatus.isClosed) {
			order.retryAfter = dtime.Timestamp() + marketStatus.opensInSeconds;
			return;
		}

		if (!validateOrder(order)) {
			CancelOrder(order);
			return;
		}

		bool isBuy = (order.side == ORDER_TYPE_BUY || order.side == ORDER_TYPE_BUY_STOP || order.side == ORDER_TYPE_BUY_LIMIT);
		ENUM_ORDER_TYPE orderType;
		double price;

		if (order.isMarketOrder) {
			orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
			price = isBuy
				? SymbolInfoDouble(symbol, SYMBOL_ASK)
				: SymbolInfoDouble(symbol, SYMBOL_BID);
		} else {
			double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
			double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
			double currentPrice = isBuy ? ask : bid;
			double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
			double minDistance = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

			price = order.openAtPrice;

			if (isBuy) {
				orderType = (order.openAtPrice < currentPrice) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
			} else {
				orderType = (order.openAtPrice > currentPrice) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
			}

			if (orderType == ORDER_TYPE_BUY_STOP && price <= ask + minDistance) {
				price = ask + minDistance + (5 * point);
			}
			if (orderType == ORDER_TYPE_SELL_STOP && price >= bid - minDistance) {
				price = bid - minDistance - (5 * point);
			}
		}

		MqlTradeResult result = trade.Open(
			symbol,
			order.GetSource() + "-" + order.GetId(),
			orderType,
			price,
			order.volume,
			order.takeProfitPrice,
			order.stopLossPrice,
			magicNumber
		);

		OnOpenOrder(order, result);
	}

	void CloseOrder(EOrder &order) {
		if (order.status == ORDER_STATUS_OPEN) {
			SMarketStatus marketStatus = GetMarketStatus(symbol);

			if (marketStatus.isClosed) {
				order.pendingToClose = true;
				order.retryAfter = dtime.Timestamp() + marketStatus.opensInSeconds;
				logger.Info(StringFormat(
					"[%s] Close pending: Market closed, will retry in %d seconds",
					order.GetId(),
					marketStatus.opensInSeconds
				));
				return;
			}

			logger.Info(StringFormat(
				"[%s] Closing open position, position_id: %llu",
				order.GetId(),
				order.GetPositionId()
			));

			if (!trade.Close(order.GetPositionId())) {
				order.retryCount++;
				logger.Error(StringFormat(
					"[%s] Failed to close open position, retry %d/%d",
					order.GetId(),
					order.retryCount,
					MAX_RETRY_COUNT
				));
				return;
			}

			logger.Info(StringFormat("[%s] Close order sent to broker, waiting for confirmation...", order.GetId()));
			order.status = ORDER_STATUS_CLOSING;
			order.pendingToClose = false;
			order.retryCount = 0;
			return;
		}

		if (order.status == ORDER_STATUS_PENDING) {
			SMarketStatus pendingMarketStatus = GetMarketStatus(symbol);

			if (pendingMarketStatus.isClosed) {
				order.pendingToClose = true;
				order.retryAfter = dtime.Timestamp() + pendingMarketStatus.opensInSeconds;

				logger.Info(StringFormat(
					"[%s] Cancel pending: Market closed, will retry in %d seconds",
					order.GetId(),
					pendingMarketStatus.opensInSeconds
				));

				return;
			}

			if (order.GetOrderId() == 0) {
				logger.Info(StringFormat("[%s] Cannot cancel order: invalid orderId", order.GetId()));
				CancelOrder(order);
				return;
			}

			if (!OrderSelect(order.GetOrderId())) {
				logger.Info(StringFormat(
					"[%s] Order no longer exists (orderId: %llu), updating status to cancelled",
					order.GetId(),
					order.GetOrderId()
				));
				CancelOrder(order);
				return;
			}

			if (!validateClose(order)) {
				order.retryCount++;
				order.pendingToClose = true;
				order.retryAfter = dtime.Timestamp() + 30;
				logger.Warning(StringFormat(
					"[%s] Cancel deferred - validation failed, retry %d",
					order.GetId(),
					order.retryCount
				));
				return;
			}

			if (!trade.Cancel(order.GetOrderId())) {
				order.retryCount++;
				order.pendingToClose = true;
				order.retryAfter = dtime.Timestamp() + 10;
				logger.Error(StringFormat(
					"[%s] Failed to cancel pending order, orderId: %llu, retry %d",
					order.GetId(),
					order.GetOrderId(),
					order.retryCount
				));
				return;
			}

			logger.Info(StringFormat("[%s] Cancel order sent to broker, waiting for confirmation...", order.GetId()));
			order.status = ORDER_STATUS_CLOSING;
			order.pendingToOpen = false;
			order.pendingToClose = false;
			order.retryCount = 0;
			return;
		}
	}

	void CancelOrder(EOrder &order) {
		order.status = ORDER_STATUS_CANCELLED;
		order.pendingToOpen = false;
		order.pendingToClose = false;
		order.isProcessed = true;
		order.closeAt = dtime.Now();
		order.BuildSnapshot();

		if (CheckPointer(orderPersistence) != POINTER_INVALID) {
			orderPersistence.SaveOrder(GetPointer(order));
		}
	}

	void OnOpenOrder(EOrder &order, const MqlTradeResult &result) {
		if (result.retcode != TRADE_RETCODE_DONE &&
		    result.retcode != TRADE_RETCODE_DONE_PARTIAL) {
			order.retryCount++;
			logger.Error(StringFormat(
				"[%s] Error opening order: %s (%d), retry %d/%d",
				order.GetId(),
				ATrade::DescribeRetcode(result.retcode),
				result.retcode,
				order.retryCount,
				MAX_RETRY_COUNT
			));

			if (order.retryCount >= MAX_RETRY_COUNT) {
				CancelOrder(order);
			}

			return;
		}

		bool wasPending = (order.status == ORDER_STATUS_PENDING);
		order.isProcessed = true;
		order.pendingToOpen = false;
		order.retryCount = 0;
		order.openAt = dtime.Now();
		order.openPrice = result.price;
		order.SetDealId(result.deal);
		order.SetOrderId(result.order);

		if (order.GetDealId() > 0) {
			HistoryDealSelect(order.GetDealId());
			order.SetPositionId(HistoryDealGetInteger(order.GetDealId(), DEAL_POSITION_ID));
		}

		if (order.GetDealId() == 0) {
			order.status = ORDER_STATUS_PENDING;
			logger.Info(StringFormat(
				"[%s] Order opened as pending, orderId: %llu",
				order.GetId(),
				order.GetOrderId()
			));

			NotifyOrderPlaced(order);
		} else {
			if (wasPending) {
				logger.Info(StringFormat(
					"[%s] Pending order has opened, dealId: %llu, positionId: %llu",
					order.GetId(),
					order.GetDealId(),
					order.GetPositionId()
				));
			} else {
				logger.Info(StringFormat(
					"[%s] Order opened immediately, dealId: %llu, positionId: %llu",
					order.GetId(),
					order.GetDealId(),
					order.GetPositionId()
				));
			}

			order.status = ORDER_STATUS_OPEN;
		}

		order.BuildSnapshot();

		if (CheckPointer(orderPersistence) != POINTER_INVALID) {
			orderPersistence.SaveOrder(GetPointer(order));
		}
	}

	void OnCloseOrder(
		EOrder &order,
		const SDateTime &time,
		double price,
		double profits,
		ENUM_DEAL_REASON reason
	) {
		order.closeAt = time;
		order.closePrice = price;
		order.profitInDollars = profits;
		order.status = ORDER_STATUS_CLOSED;

		if (profits == 0.0 && price == 0.0) {
			order.status = ORDER_STATUS_CANCELLED;
			logger.Info(StringFormat("[%s] Order cancelled", order.GetId()));
		}

		order.orderCloseReason = reason;
		order.BuildSnapshot();

		switch (reason) {
		case DEAL_REASON_TP:
			logger.Info(StringFormat("[%s] Order closed by Take Profit", order.GetId()));
			break;
		case DEAL_REASON_EXPERT:
			logger.Info(StringFormat("[%s] Order closed by Expert", order.GetId()));
			break;
		case DEAL_REASON_CLIENT:
			logger.Info(StringFormat("[%s] Order closed by Client", order.GetId()));
			break;
		case DEAL_REASON_MOBILE:
			logger.Info(StringFormat("[%s] Order closed by Mobile", order.GetId()));
			break;
		case DEAL_REASON_WEB:
			logger.Info(StringFormat("[%s] Order closed by Web", order.GetId()));
			break;
		case DEAL_REASON_SL:
			logger.Info(StringFormat("[%s] Order closed by Stop Loss", order.GetId()));
			break;
		default:
			break;
		}

		if (CheckPointer(orderPersistence) != POINTER_INVALID) {
			orderPersistence.SaveOrder(GetPointer(order));
		}
	}

	bool ModifyStopLoss(EOrder &order, double newStopLossPrice) {
		if (newStopLossPrice <= 0) {
			return false;
		}

		if (order.status == ORDER_STATUS_OPEN) {
			trade.SetPositionId(order.GetPositionId());

			if (!trade.ModifyStopLoss(newStopLossPrice, magicNumber)) {
				logger.Error(StringFormat("[%s] Failed to modify stop loss on open position", order.GetId()));
				return false;
			}

			logger.Info(StringFormat(
				"[%s] Stop loss modified to: %.*f",
				order.GetId(),
				(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
				newStopLossPrice
			));
		}

		order.stopLossPrice = newStopLossPrice;
		return true;
	}

	bool ModifyTakeProfit(EOrder &order, double newTakeProfitPrice) {
		if (newTakeProfitPrice <= 0) {
			return false;
		}

		if (order.status == ORDER_STATUS_OPEN) {
			trade.SetPositionId(order.GetPositionId());

			if (!trade.ModifyTakeProfit(newTakeProfitPrice, magicNumber)) {
				logger.Error(StringFormat("[%s] Failed to modify take profit on open position", order.GetId()));
				return false;
			}

			logger.Info(StringFormat(
				"[%s] Take profit modified to: %.*f",
				order.GetId(),
				(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
				newTakeProfitPrice
			));
		}

		order.takeProfitPrice = newTakeProfitPrice;
		return true;
	}

	bool ModifyStopLossAndTakeProfit(EOrder &order, double newStopLossPrice, double newTakeProfitPrice) {
		if (newStopLossPrice <= 0 && newTakeProfitPrice <= 0) {
			return false;
		}

		if (order.status == ORDER_STATUS_OPEN) {
			trade.SetPositionId(order.GetPositionId());

			if (!trade.ModifyStopLossAndTakeProfit(newStopLossPrice, newTakeProfitPrice, magicNumber)) {
				logger.Error(StringFormat("[%s] Failed to modify SL/TP on open position", order.GetId()));
				return false;
			}

			logger.Info(StringFormat(
				"[%s] SL/TP modified to: sl=%.*f tp=%.*f",
				order.GetId(),
				(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
				newStopLossPrice,
				(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
				newTakeProfitPrice
			));
		}

		if (newStopLossPrice > 0) {
			order.stopLossPrice = newStopLossPrice;
		}

		if (newTakeProfitPrice > 0) {
			order.takeProfitPrice = newTakeProfitPrice;
		}

		return true;
	}

	double GetFloatingProfitAndLoss(EOrder &order) {
		if (order.status != ORDER_STATUS_OPEN) {
			return 0.0;
		}

		if (order.GetPositionId() == 0) {
			return 0.0;
		}

		if (!PositionSelectByTicket(order.GetPositionId())) {
			return 0.0;
		}

		return PositionGetDouble(POSITION_PROFIT) +
		       PositionGetDouble(POSITION_SWAP);
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

	EOrder * GetOrderAtIndex(int index) {
		if (index < 0 || index >= ArraySize(orders)) {
			return NULL;
		}

		return GetPointer(orders[index]);
	}

	int GetOrdersCount() {
		return ArraySize(orders);
	}

	int GetOpenOrderCount() {
		return openOrderCount;
	}

	int GetClosedOrderCount() {
		return closedOrderCount;
	}

	int GetTodayOrderCount() {
		return todayOrderCount;
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

	void PurgeClosedOrders() {
		datetime threshold = dtime.Timestamp() - SECONDS_IN_24_HOURS;
		int writeIndex = 0;
		string idsToPurge[];

		for (int i = 0; i < ArraySize(orders); i++) {
			ENUM_ORDER_STATUSES orderStatus = orders[i].GetStatus();
			bool isDead = (orderStatus == ORDER_STATUS_CLOSED || orderStatus == ORDER_STATUS_CANCELLED);
			bool isOldEnough = (orders[i].GetCloseAt().timestamp > 0 && orders[i].GetCloseAt().timestamp < threshold);

			if (isDead && isOldEnough) {
				int purgeSize = ArraySize(idsToPurge);
				ArrayResize(idsToPurge, purgeSize + 1);
				idsToPurge[purgeSize] = orders[i].GetId();
				continue;
			}

			if (writeIndex != i) {
				orders[writeIndex] = orders[i];
			}

			writeIndex++;
		}

		int purged = ArraySize(idsToPurge);

		if (purged > 0) {
			ArrayResize(orders, writeIndex);

			if (CheckPointer(orderPersistence) != POINTER_INVALID) {
				for (int i = 0; i < purged; i++) {
					orderPersistence.DeleteOrder(idsToPurge[i]);
				}
			}

			logger.Info(StringFormat("Purged %d closed orders from memory and database", purged));
		}
	}

	void ResetTodayOrderCount() {
		todayOrderCount = 0;
	}

	void IncrementOpenOrderCount() {
		openOrderCount++;
	}

	void OnOrderOpened() {
	}

	void OnOrderClosed() {
		openOrderCount--;
		closedOrderCount++;
	}

	void OnOrderCancelled() {
		openOrderCount--;
		closedOrderCount++;
	}

	void OnDeinit() {
		for (int i = 0; i < ArraySize(orders); i++) {
			orders[i].OnDeinit();
		}

		ArrayResize(orders, 0);
	}

	int RestoreOrders(EOrder &reconciledOrders[]) {
		if (CheckPointer(orderPersistence) == POINTER_INVALID) {
			return 0;
		}

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
			ENUM_ORDER_STATUSES orderStatus = restoredOrders[i].GetStatus();

			if (orderStatus == ORDER_STATUS_CLOSED || orderStatus == ORDER_STATUS_CANCELLED) {
				int reconciledSize = ArraySize(reconciledOrders);
				ArrayResize(reconciledOrders, reconciledSize + 1);
				reconciledOrders[reconciledSize] = restoredOrders[i];
				continue;
			}

			if (FindOrderIndexById(restoredOrders[i].GetId()) != -1) {
				continue;
			}

			restoredOrders[i].OnInit();
			AddOrder(restoredOrders[i]);
			totalRestored++;
			openOrderCount++;
		}

		if (totalRestored > 0) {
			logger.Info(StringFormat("Restored %d active orders from JSON", totalRestored));
		}

		return totalRestored;
	}

	int QueryPersistedOrders(SEDbQuery &query, JSON::Object *&results[]) {
		if (CheckPointer(orderPersistence) == POINTER_INVALID) {
			ArrayResize(results, 0);
			return 0;
		}

		return orderPersistence.QueryOrders(query, results);
	}

private:
	void NotifyOrderCancelled(EOrder &order);
	void NotifyOrderPlaced(EOrder &order);

	bool validateOrder(EOrder &order) {
		bool isBuy = (order.side == ORDER_TYPE_BUY || order.side == ORDER_TYPE_BUY_STOP || order.side == ORDER_TYPE_BUY_LIMIT);
		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

		ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
		if (tradeMode == SYMBOL_TRADE_MODE_DISABLED) {
			logger.Warning(StringFormat("[%s] Validation failed - Trading disabled for %s", order.GetId(), symbol));
			return false;
		}
		if (tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY) {
			logger.Warning(StringFormat("[%s] Validation failed - %s is in close-only mode", order.GetId(), symbol));
			return false;
		}
		if (tradeMode == SYMBOL_TRADE_MODE_LONGONLY && !isBuy) {
			logger.Warning(StringFormat("[%s] Validation failed - %s allows long positions only", order.GetId(), symbol));
			return false;
		}
		if (tradeMode == SYMBOL_TRADE_MODE_SHORTONLY && isBuy) {
			logger.Warning(StringFormat("[%s] Validation failed - %s allows short positions only", order.GetId(), symbol));
			return false;
		}

		if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
			logger.Warning(StringFormat("[%s] Validation failed - Trading not allowed on account", order.GetId()));
			return false;
		}
		if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
			logger.Warning(StringFormat("[%s] Validation failed - AutoTrading disabled in terminal", order.GetId()));
			return false;
		}

		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (order.volume <= 0) {
			logger.Warning(StringFormat("[%s] Validation failed - Volume is zero or negative: %.5f", order.GetId(), order.volume));
			return false;
		}

		order.volume = MathFloor(order.volume / lotStep) * lotStep;
		order.volume = NormalizeDouble(order.volume, 2);

		if (order.volume < minLot) {
			logger.Warning(StringFormat("[%s] Validation failed - Volume %.5f below minimum %.5f", order.GetId(), order.volume, minLot));
			return false;
		}
		if (order.volume > maxLot) {
			logger.Warning(StringFormat("[%s] Validation failed - Volume %.5f exceeds maximum %.5f, clamped", order.GetId(), order.volume, maxLot));
			order.volume = maxLot;
		}

		long maxOrders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
		if (maxOrders > 0 && (OrdersTotal() + PositionsTotal()) >= (int)maxOrders) {
			logger.Warning(StringFormat("[%s] Validation failed - Account order limit reached (%d/%d)", order.GetId(), OrdersTotal() + PositionsTotal(), maxOrders));
			return false;
		}

		if (!order.isMarketOrder && order.openAtPrice <= 0) {
			logger.Warning(StringFormat("[%s] Validation failed - Pending order price is invalid: %.*f", order.GetId(), digits, order.openAtPrice));
			return false;
		}

		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
		long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
		double minStopsDistance = stopsLevel * point;
		double entryPrice = order.isMarketOrder ? (isBuy ? ask : bid) : order.openAtPrice;

		if (order.stopLossPrice > 0) {
			if (isBuy && order.stopLossPrice >= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - BUY stop loss %.*f must be below entry price %.*f", order.GetId(), digits, order.stopLossPrice, digits, entryPrice));
				return false;
			}
			if (!isBuy && order.stopLossPrice <= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - SELL stop loss %.*f must be above entry price %.*f", order.GetId(), digits, order.stopLossPrice, digits, entryPrice));
				return false;
			}
			if (minStopsDistance > 0 && MathAbs(entryPrice - order.stopLossPrice) < minStopsDistance) {
				logger.Warning(StringFormat("[%s] Validation failed - Stop loss too close to entry, distance: %.*f, minimum: %.*f", order.GetId(), digits, MathAbs(entryPrice - order.stopLossPrice), digits, minStopsDistance));
				return false;
			}
		}

		if (order.takeProfitPrice > 0) {
			if (isBuy && order.takeProfitPrice <= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - BUY take profit %.*f must be above entry price %.*f", order.GetId(), digits, order.takeProfitPrice, digits, entryPrice));
				return false;
			}
			if (!isBuy && order.takeProfitPrice >= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - SELL take profit %.*f must be below entry price %.*f", order.GetId(), digits, order.takeProfitPrice, digits, entryPrice));
				return false;
			}
			if (minStopsDistance > 0 && MathAbs(entryPrice - order.takeProfitPrice) < minStopsDistance) {
				logger.Warning(StringFormat("[%s] Validation failed - Take profit too close to entry, distance: %.*f, minimum: %.*f", order.GetId(), digits, MathAbs(entryPrice - order.takeProfitPrice), digits, minStopsDistance));
				return false;
			}
		}

		double requiredMargin = 0;
		ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
		if (!OrderCalcMargin(orderType, symbol, order.volume, entryPrice, requiredMargin)) {
			logger.Warning(StringFormat("[%s] Validation failed - Cannot calculate required margin", order.GetId()));
			return false;
		}
		double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
		if (requiredMargin > freeMargin) {
			logger.Warning(StringFormat("[%s] Validation failed - Insufficient margin, required: %.2f, free: %.2f", order.GetId(), requiredMargin, freeMargin));
			return false;
		}

		return true;
	}

	bool validateClose(EOrder &order) {
		if (order.status == ORDER_STATUS_PENDING) {
			long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
			if (freezeLevel > 0 && order.openAtPrice > 0) {
				double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
				double freezeDistance = freezeLevel * point;
				int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
				double currentPrice = (order.side == ORDER_TYPE_BUY || order.side == ORDER_TYPE_BUY_STOP || order.side == ORDER_TYPE_BUY_LIMIT)
					? SymbolInfoDouble(symbol, SYMBOL_ASK)
					: SymbolInfoDouble(symbol, SYMBOL_BID);

				if (MathAbs(currentPrice - order.openAtPrice) <= freezeDistance) {
					logger.Warning(StringFormat(
						"[%s] Close validation failed - Pending order price within freeze level (distance: %.*f, freeze: %.*f)",
						order.GetId(), digits, MathAbs(currentPrice - order.openAtPrice), digits, freezeDistance
					));
					return false;
				}
			}
		}

		return true;
	}

	void filterOrders(
		EOrder& resultOrders[],
		ENUM_ORDER_TYPE side,
		ENUM_ORDER_STATUSES status,
		ENUM_ORDER_STATUSES defaultStatus1,
		ENUM_ORDER_STATUSES defaultStatus2 = ORDER_STATUS_ANY
	) {
		ArrayResize(resultOrders, 0, ArraySize(orders));

		int resultCount = 0;

		for (int i = 0; i < ArraySize(orders); i++) {
			bool isSideMatch = (side == ORDER_TYPE_ANY) || (orders[i].GetSide() == side);
			bool isStatusMatch = false;

			if (status == ORDER_STATUS_ANY) {
				isStatusMatch = (orders[i].GetStatus() == defaultStatus1);
				if (defaultStatus2 != ORDER_STATUS_ANY) {
					isStatusMatch = isStatusMatch || (orders[i].GetStatus() == defaultStatus2);
				}
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
};

#endif
