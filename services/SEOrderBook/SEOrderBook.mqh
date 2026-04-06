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

#include "../../entities/EAccount.mqh"
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
	EAccount account;
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

	string BuildOrderComment(EOrder &order) {
		string cleanSymbol = symbol;
		StringReplace(cleanSymbol, ".", "");

		string orderId = order.GetId();
		StringReplace(orderId, "-", "");
		string shortId = StringSubstr(orderId, 0, 8);

		string comment = "HRZ" + cleanSymbol + order.GetSource() + shortId;
		StringToUpper(comment);

		return comment;
	}

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
		double currentPrice = isBuySide(side) ? askPrice : bidPrice;

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
			order.SetStopLossPrice(stopLoss);
		}

		if (takeProfit > 0) {
			order.SetTakeProfitPrice(takeProfit);
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
				if (orders[i].IsPendingToClose()) {
					CheckToCancel(orders[i]);
				} else if (tradingStatus.isPaused) {
					CloseOrder(orders[i]);
				} else {
					CheckToOpen(orders[i]);
				}
			}

			if (statusBefore == ORDER_STATUS_OPEN) {
				CheckToClose(orders[i]);
			}
		}
	}

	void CloseAllActiveOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			ENUM_ORDER_STATUSES status = orders[i].GetStatus();

			if (status == ORDER_STATUS_OPEN || status == ORDER_STATUS_PENDING) {
				CloseOrder(orders[i]);
			}
		}
	}

	void CancelAllPendingOrders() {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (orders[i].GetStatus() == ORDER_STATUS_PENDING) {
				CloseOrder(orders[i]);
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
		if (!order.IsPendingToOpen() || order.IsProcessed()) {
			return;
		}

		datetime currentTime = dtime.Timestamp();

		if (order.GetRetryAfter() > 0 && currentTime < order.GetRetryAfter()) {
			return;
		}

		if (order.GetRetryCount() >= MAX_RETRY_COUNT) {
			logger.Error(StringFormat("[%s] Max retry count reached, cancelling order", order.GetId()));
			CancelOrder(order);
			return;
		}

		logger.Info(StringFormat("[%s] Opening order", order.GetId()));
		OpenOrder(order);
	}

	void CheckToCancel(EOrder &order) {
		datetime currentTime = dtime.Timestamp();

		if (order.GetRetryAfter() > 0 && currentTime < order.GetRetryAfter()) {
			return;
		}

		if (order.GetOrderId() > 0 && !OrderSelect(order.GetOrderId())) {
			CancelOrder(order);
			return;
		}

		CloseOrder(order);
	}

	void CheckToClose(EOrder &order) {
		if (!order.IsPendingToClose()) {
			return;
		}

		datetime currentTime = dtime.Timestamp();

		if (order.GetRetryAfter() > 0 && currentTime < order.GetRetryAfter()) {
			return;
		}

		if (order.GetRetryCount() >= MAX_RETRY_COUNT) {
			logger.Error(StringFormat("[%s] Max retry count reached for close, giving up", order.GetId()));
			order.SetPendingToClose(false);
			order.SetRetryCount(0);
			return;
		}

		CloseOrder(order);
	}

	void OpenOrder(EOrder &order) {
		SMarketStatus marketStatus = GetMarketStatus(symbol);

		if (marketStatus.isClosed) {
			order.SetRetryAfter(dtime.Timestamp() + marketStatus.opensInSeconds);
			return;
		}

		if (!validateOrder(order)) {
			CancelOrder(order);
			return;
		}

		bool isBuy = isBuySide(order.GetSide());
		ENUM_ORDER_TYPE orderType;
		double price;

		if (order.IsMarketOrder()) {
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

			price = order.GetOpenAtPrice();

			if (isBuy) {
				orderType = (order.GetOpenAtPrice() < currentPrice) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
			} else {
				orderType = (order.GetOpenAtPrice() > currentPrice) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
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
			BuildOrderComment(order),
			orderType,
			price,
			order.GetVolume(),
			order.GetTakeProfitPrice(),
			order.GetStopLossPrice(),
			magicNumber
		);

		OnOpenOrder(order, result);
	}

	void CloseOrder(EOrder &order) {
		if (order.GetStatus() == ORDER_STATUS_OPEN) {
			SMarketStatus marketStatus = GetMarketStatus(symbol);

			if (marketStatus.isClosed) {
				order.SetPendingToClose(true);
				order.SetRetryAfter(dtime.Timestamp() + marketStatus.opensInSeconds);
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
				order.SetRetryCount(order.GetRetryCount() + 1);
				logger.Error(StringFormat(
					"[%s] Failed to close open position, retry %d/%d",
					order.GetId(),
					order.GetRetryCount(),
					MAX_RETRY_COUNT
				));
				return;
			}

			logger.Info(StringFormat("[%s] Close order sent to broker, waiting for confirmation...", order.GetId()));
			order.SetStatus(ORDER_STATUS_CLOSING);
			order.SetPendingToClose(false);
			order.SetRetryCount(0);

			if (CheckPointer(orderPersistence) != POINTER_INVALID) {
				orderPersistence.SaveOrder(GetPointer(order));
			}

			NotifyOrderUpdated(order);
			return;
		}

		if (order.GetStatus() == ORDER_STATUS_PENDING) {
			SMarketStatus pendingMarketStatus = GetMarketStatus(symbol);

			if (pendingMarketStatus.isClosed) {
				order.SetPendingToClose(true);
				order.SetRetryAfter(dtime.Timestamp() + pendingMarketStatus.opensInSeconds);

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
				order.SetRetryCount(order.GetRetryCount() + 1);
				order.SetPendingToClose(true);
				order.SetRetryAfter(dtime.Timestamp() + 30);
				logger.Warning(StringFormat(
					"[%s] Cancel deferred - validation failed, retry %d",
					order.GetId(),
					order.GetRetryCount()
				));
				return;
			}

			if (!trade.Cancel(order.GetOrderId())) {
				order.SetRetryCount(order.GetRetryCount() + 1);
				order.SetPendingToClose(true);
				order.SetRetryAfter(dtime.Timestamp() + 10);
				logger.Error(StringFormat(
					"[%s] Failed to cancel pending order, orderId: %llu, retry %d",
					order.GetId(),
					order.GetOrderId(),
					order.GetRetryCount()
				));
				return;
			}

			logger.Info(StringFormat("[%s] Cancel order sent to broker, waiting for confirmation...", order.GetId()));
			order.SetStatus(ORDER_STATUS_CLOSING);
			order.SetPendingToOpen(false);
			order.SetPendingToClose(false);
			order.SetRetryCount(0);

			if (CheckPointer(orderPersistence) != POINTER_INVALID) {
				orderPersistence.SaveOrder(GetPointer(order));
			}

			NotifyOrderUpdated(order);
			return;
		}
	}

	void CancelOrder(EOrder &order) {
		order.SetStatus(ORDER_STATUS_CANCELLED);
		order.SetPendingToOpen(false);
		order.SetPendingToClose(false);
		order.SetIsProcessed(true);
		SDateTime cancelTime = dtime.Now();
		order.SetCloseAt(cancelTime);
		order.BuildSnapshot();

		if (CheckPointer(orderPersistence) != POINTER_INVALID) {
			orderPersistence.SaveOrder(GetPointer(order));
		}

		NotifyOrderCancelled(order);
	}

	void OnOpenOrder(EOrder &order, const MqlTradeResult &result) {
		if (result.retcode != TRADE_RETCODE_DONE &&
		    result.retcode != TRADE_RETCODE_DONE_PARTIAL) {
			order.SetRetryCount(order.GetRetryCount() + 1);
			logger.Error(StringFormat(
				"[%s] Error opening order: %s (%d), retry %d/%d",
				order.GetId(),
				ATrade::DescribeRetcode(result.retcode),
				result.retcode,
				order.GetRetryCount(),
				MAX_RETRY_COUNT
			));

			if (order.GetRetryCount() >= MAX_RETRY_COUNT) {
				CancelOrder(order);
			}

			return;
		}

		bool wasPending = (order.GetStatus() == ORDER_STATUS_PENDING);
		order.SetIsProcessed(true);
		order.SetPendingToOpen(false);
		order.SetRetryCount(0);
		SDateTime openTime = dtime.Now();
		order.SetOpenAt(openTime);
		order.SetOpenPrice(result.price);
		order.SetDealId(result.deal);
		order.SetOrderId(result.order);

		if (order.GetDealId() > 0) {
			HistoryDealSelect(order.GetDealId());
			order.SetPositionId(HistoryDealGetInteger(order.GetDealId(), DEAL_POSITION_ID));
		}

		if (order.GetDealId() == 0) {
			order.SetStatus(ORDER_STATUS_PENDING);
			logger.Info(StringFormat(
				"[%s] Order opened as pending, orderId: %llu",
				order.GetId(),
				order.GetOrderId()
			));

			NotifyOrderPlaced(order);
		} else {
			if (wasPending) {
				logger.Success(StringFormat(
					"[%s] Pending order has opened, dealId: %llu, positionId: %llu",
					order.GetId(),
					order.GetDealId(),
					order.GetPositionId()
				));
			} else {
				logger.Success(StringFormat(
					"[%s] Order opened immediately, dealId: %llu, positionId: %llu",
					order.GetId(),
					order.GetDealId(),
					order.GetPositionId()
				));
			}

			order.SetStatus(ORDER_STATUS_OPEN);
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
		order.SetCloseAt(time);
		order.SetClosePrice(price);
		order.SetProfitInDollars(profits);
		order.SetStatus(ORDER_STATUS_CLOSED);

		if (profits == 0.0 && price == 0.0) {
			order.SetStatus(ORDER_STATUS_CANCELLED);
			logger.Error(StringFormat("[%s] Order cancelled", order.GetId()));
		}

		order.SetCloseReason(reason);
		order.BuildSnapshot();

		switch (reason) {
		case DEAL_REASON_TP:
			logger.Success(StringFormat("[%s] Order closed by Take Profit", order.GetId()));
			break;
		case DEAL_REASON_EXPERT:
			logger.Success(StringFormat("[%s] Order closed by Expert", order.GetId()));
			break;
		case DEAL_REASON_CLIENT:
			logger.Success(StringFormat("[%s] Order closed by Client", order.GetId()));
			break;
		case DEAL_REASON_MOBILE:
			logger.Success(StringFormat("[%s] Order closed by Mobile", order.GetId()));
			break;
		case DEAL_REASON_WEB:
			logger.Success(StringFormat("[%s] Order closed by Web", order.GetId()));
			break;
		case DEAL_REASON_SL:
			logger.Success(StringFormat("[%s] Order closed by Stop Loss", order.GetId()));
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

		if (order.GetStatus() == ORDER_STATUS_OPEN) {
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

		order.SetStopLossPrice(newStopLossPrice);
		return true;
	}

	bool ModifyTakeProfit(EOrder &order, double newTakeProfitPrice) {
		if (newTakeProfitPrice <= 0) {
			return false;
		}

		if (order.GetStatus() == ORDER_STATUS_OPEN) {
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

		order.SetTakeProfitPrice(newTakeProfitPrice);
		return true;
	}

	bool ModifyStopLossAndTakeProfit(EOrder &order, double newStopLossPrice, double newTakeProfitPrice) {
		if (newStopLossPrice <= 0 && newTakeProfitPrice <= 0) {
			return false;
		}

		if (order.GetStatus() == ORDER_STATUS_OPEN) {
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
			order.SetStopLossPrice(newStopLossPrice);
		}

		if (newTakeProfitPrice > 0) {
			order.SetTakeProfitPrice(newTakeProfitPrice);
		}

		return true;
	}

	double GetFloatingProfitAndLoss(EOrder &order) {
		if (order.GetStatus() != ORDER_STATUS_OPEN) {
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
	void NotifyOrderUpdated(EOrder &order);

	bool isBuySide(int side) {
		return side == ORDER_TYPE_BUY || side == ORDER_TYPE_BUY_STOP || side == ORDER_TYPE_BUY_LIMIT;
	}

	bool validateOrder(EOrder &order) {
		bool isBuy = isBuySide(order.GetSide());

		if (!validateTradeMode(order, isBuy)) {
			return false;
		}

		if (!validateVolume(order)) {
			return false;
		}

		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

		if (!order.IsMarketOrder() && order.GetOpenAtPrice() <= 0) {
			logger.Warning(StringFormat("[%s] Validation failed - Pending order price is invalid: %.*f", order.GetId(), digits, order.GetOpenAtPrice()));
			return false;
		}

		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		double entryPrice = order.IsMarketOrder() ? (isBuy ? ask : bid) : order.GetOpenAtPrice();

		if (!validateStopLevels(order, isBuy, entryPrice, digits)) {
			return false;
		}

		if (!validateMargin(order, isBuy, entryPrice)) {
			return false;
		}

		return true;
	}

	bool validateTradeMode(EOrder &order, bool isBuy) {
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

		if (!account.IsTradeAllowed()) {
			logger.Warning(StringFormat("[%s] Validation failed - Trading not allowed on account", order.GetId()));
			return false;
		}

		if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
			logger.Warning(StringFormat("[%s] Validation failed - AutoTrading disabled in terminal", order.GetId()));
			return false;
		}

		long maxOrders = account.GetMaxOrders();
		if (maxOrders > 0 && (OrdersTotal() + PositionsTotal()) >= (int)maxOrders) {
			logger.Warning(StringFormat("[%s] Validation failed - Account order limit reached (%d/%d)", order.GetId(), OrdersTotal() + PositionsTotal(), maxOrders));
			return false;
		}

		return true;
	}

	bool validateVolume(EOrder &order) {
		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (order.GetVolume() <= 0) {
			logger.Warning(StringFormat("[%s] Validation failed - Volume is zero or negative: %.5f", order.GetId(), order.GetVolume()));
			return false;
		}

		double normalizedVolume = MathFloor(order.GetVolume() / lotStep) * lotStep;
		normalizedVolume = NormalizeDouble(normalizedVolume, 2);
		order.SetVolume(normalizedVolume);

		if (order.GetVolume() < minLot) {
			logger.Warning(StringFormat("[%s] Validation failed - Volume %.5f below minimum %.5f", order.GetId(), order.GetVolume(), minLot));
			return false;
		}

		if (order.GetVolume() > maxLot) {
			logger.Warning(StringFormat("[%s] Validation failed - Volume %.5f exceeds maximum %.5f, clamped", order.GetId(), order.GetVolume(), maxLot));
			order.SetVolume(maxLot);
		}

		return true;
	}

	bool validateStopLevels(EOrder &order, bool isBuy, double entryPrice, int digits) {
		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
		long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
		double minStopsDistance = stopsLevel * point;

		if (order.GetStopLossPrice() > 0) {
			if (isBuy && order.GetStopLossPrice() >= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - BUY stop loss %.*f must be below entry price %.*f", order.GetId(), digits, order.GetStopLossPrice(), digits, entryPrice));
				return false;
			}

			if (!isBuy && order.GetStopLossPrice() <= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - SELL stop loss %.*f must be above entry price %.*f", order.GetId(), digits, order.GetStopLossPrice(), digits, entryPrice));
				return false;
			}

			if (minStopsDistance > 0 && MathAbs(entryPrice - order.GetStopLossPrice()) < minStopsDistance) {
				logger.Warning(StringFormat("[%s] Validation failed - Stop loss too close to entry, distance: %.*f, minimum: %.*f", order.GetId(), digits, MathAbs(entryPrice - order.GetStopLossPrice()), digits, minStopsDistance));
				return false;
			}
		}

		if (order.GetTakeProfitPrice() > 0) {
			if (isBuy && order.GetTakeProfitPrice() <= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - BUY take profit %.*f must be above entry price %.*f", order.GetId(), digits, order.GetTakeProfitPrice(), digits, entryPrice));
				return false;
			}

			if (!isBuy && order.GetTakeProfitPrice() >= entryPrice) {
				logger.Warning(StringFormat("[%s] Validation failed - SELL take profit %.*f must be below entry price %.*f", order.GetId(), digits, order.GetTakeProfitPrice(), digits, entryPrice));
				return false;
			}

			if (minStopsDistance > 0 && MathAbs(entryPrice - order.GetTakeProfitPrice()) < minStopsDistance) {
				logger.Warning(StringFormat("[%s] Validation failed - Take profit too close to entry, distance: %.*f, minimum: %.*f", order.GetId(), digits, MathAbs(entryPrice - order.GetTakeProfitPrice()), digits, minStopsDistance));
				return false;
			}
		}

		return true;
	}

	bool validateMargin(EOrder &order, bool isBuy, double entryPrice) {
		double requiredMargin = 0;
		ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

		if (!OrderCalcMargin(orderType, symbol, order.GetVolume(), entryPrice, requiredMargin)) {
			logger.Warning(StringFormat("[%s] Validation failed - Cannot calculate required margin", order.GetId()));
			return false;
		}

		double freeMargin = account.GetFreeMargin();

		if (requiredMargin > freeMargin) {
			logger.Warning(StringFormat("[%s] Validation failed - Insufficient margin, required: %.2f, free: %.2f", order.GetId(), requiredMargin, freeMargin));
			return false;
		}

		return true;
	}

	bool validateClose(EOrder &order) {
		if (order.GetStatus() == ORDER_STATUS_PENDING) {
			long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
			if (freezeLevel > 0 && order.GetOpenAtPrice() > 0) {
				double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
				double freezeDistance = freezeLevel * point;
				int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
				double currentPrice = isBuySide(order.GetSide())
				? SymbolInfoDouble(symbol, SYMBOL_ASK)
				: SymbolInfoDouble(symbol, SYMBOL_BID);

				if (MathAbs(currentPrice - order.GetOpenAtPrice()) <= freezeDistance) {
					logger.Warning(StringFormat(
						"[%s] Close validation failed - Pending order price within freeze level (distance: %.*f, freeze: %.*f)",
						order.GetId(), digits, MathAbs(currentPrice - order.GetOpenAtPrice()), digits, freezeDistance
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
