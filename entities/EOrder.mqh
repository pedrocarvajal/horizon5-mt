#ifndef __E_ORDER_MQH__
#define __E_ORDER_MQH__

#include "../enums/EOrderStatuses.mqh"
#include "../structs/SSOrderHistory.mqh"
#include "../adapters/ATrade.mqh"
#include "../services/SEDateTime/SEDateTime.mqh"
#include "../services/SEDateTime/structs/SDateTime.mqh"
#include "../helpers/HIsMarketClosed.mqh"

#define MAX_RETRY_COUNT 3

class SEOrderPersistence;

extern SEDateTime dtime;

class EOrder:
public ATrade {
public:
	SEOrderPersistence * persistence;
	bool isInitialized;
	bool isProcessed;
	bool isMarketOrder;
	bool pendingToOpen;
	bool pendingToClose;

	string id;
	string source;
	string symbol;
	ulong magicNumber;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON orderCloseReason;
	int retryCount;
	datetime retryAfter;

	double volume;
	double signalPrice;
	double openAtPrice;
	double openPrice;
	double closePrice;
	double profitInDollars;
	double takeProfitPrice;
	double stopLossPrice;

	SDateTime signalAt;
	SDateTime openAt;
	SDateTime closeAt;

	SSOrderHistory snapshot;
	SELogger logger;

	EOrder(ulong strategyMagicNumber = 0, string strategySymbol = "") {
		logger.SetPrefix("Order");

		symbol = strategySymbol;
		magicNumber = strategyMagicNumber;
		persistence = NULL;

		isInitialized = false;
		isProcessed = false;
		isMarketOrder = false;
		pendingToOpen = true;
		pendingToClose = false;
		retryCount = 0;
		retryAfter = 0;
		id = "";
		SetDealId(0);
		SetOrderId(0);
		SetPositionId(0);
	}

	EOrder(const EOrder& other) {
		logger.SetPrefix("Order");

		persistence = other.persistence;
		isInitialized = other.isInitialized;
		isProcessed = other.isProcessed;
		isMarketOrder = other.isMarketOrder;
		pendingToOpen = other.pendingToOpen;
		pendingToClose = other.pendingToClose;
		retryCount = other.retryCount;
		retryAfter = other.retryAfter;

		id = other.id;
		source = other.source;
		symbol = other.symbol;
		magicNumber = other.magicNumber;

		status = other.status;
		side = other.side;
		orderCloseReason = other.orderCloseReason;

		volume = other.volume;

		signalPrice = other.signalPrice;
		openAtPrice = other.openAtPrice;
		openPrice = other.openPrice;
		closePrice = other.closePrice;

		signalAt = other.signalAt;
		openAt = other.openAt;
		closeAt = other.closeAt;

		profitInDollars = other.profitInDollars;

		takeProfitPrice = other.takeProfitPrice;
		stopLossPrice = other.stopLossPrice;

		snapshot = other.snapshot;

		SetDealId(other.GetDealId());
		SetOrderId(other.GetOrderId());
		SetPositionId(other.GetPositionId());
	}

private:
	void Snapshot() {
		snapshot.orderId = GetId();
		snapshot.symbol = symbol;
		snapshot.strategyName = source;
		snapshot.strategyPrefix = source;
		snapshot.magicNumber = magicNumber;
		snapshot.dealId = GetDealId();
		snapshot.positionId = GetPositionId();
		snapshot.status = status;
		snapshot.side = side;
		snapshot.orderCloseReason = orderCloseReason;
		snapshot.takeProfitPrice = takeProfitPrice;
		snapshot.stopLossPrice = stopLossPrice;
		snapshot.signalAt = signalAt.timestamp;
		snapshot.signalPrice = signalPrice;
		snapshot.openTime = openAt.timestamp;
		snapshot.openPrice = openPrice;
		snapshot.openLot = volume;
		snapshot.closeTime = closeAt.timestamp;
		snapshot.closePrice = closePrice;
		snapshot.profitInDollars = profitInDollars;
	}

	void RefreshId() {
		string uuid = "";
		for (int i = 0; i < 8; i++)
			uuid += IntegerToString(MathRand() % 10);
		id = StringFormat("%s_%s", source, uuid);
	}

	bool ValidateMinimumVolume() {
		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (volume <= 0) {
			logger.info(StringFormat(
				"[%s] Validation failed - Volume is zero or negative: %.5f",
				GetId(),
				volume
			));
			return false;
		}

		if (volume < minLot) {
			logger.info(StringFormat(
				"[%s] Validation failed - Volume %.5f is below minimum lot size: %.5f",
				GetId(),
				volume,
				minLot
			));
			return false;
		}

		if (volume > maxLot) {
			logger.info(StringFormat(
				"[%s] Validation failed - Volume %.5f exceeds maximum lot size: %.5f",
				GetId(),
				volume,
				maxLot
			));
			return false;
		}

		double normalizedVolume = MathFloor(volume / lotStep) * lotStep;
		if (normalizedVolume < minLot) {
			logger.info(StringFormat(
				"[%s] Validation failed - Normalized volume %.5f is below minimum after lot step adjustment",
				GetId(),
				normalizedVolume
			));
			return false;
		}

		return true;
	}

public:
	void OnInit() {
		if (isInitialized) {
			logger.info(StringFormat("[%s] Order already initialized", GetId()));
			return;
		}

		isInitialized = true;
	}

	void CheckToOpen() {
		if (!pendingToOpen || isProcessed)
			return;

		datetime currentTime = dtime.Timestamp();
		SMarketStatus marketStatus = getMarketStatus(symbol);

		if (retryAfter > 0 && currentTime < retryAfter)
			return;

		if (retryCount >= MAX_RETRY_COUNT) {
			logger.warning(StringFormat("[%s] Max retry count reached, cancelling order", GetId()));
			Cancel();
			return;
		}

		if (marketStatus.isClosed) {
			retryAfter = currentTime + marketStatus.opensInSeconds;
			logger.info(StringFormat(
				"[%s] Open pending: Market closed, will retry in %d seconds",
				GetId(),
				marketStatus.opensInSeconds
			));
			return;
		}

		logger.info(StringFormat("[%s] Opening order, id: %s", GetId(), GetId()));
		Open();
	}

	void CheckToClose() {
		if (!pendingToClose)
			return;

		datetime currentTime = dtime.Timestamp();
		SMarketStatus marketStatus = getMarketStatus(symbol);

		if (retryAfter > 0 && currentTime < retryAfter)
			return;

		if (retryCount >= MAX_RETRY_COUNT) {
			logger.warning(StringFormat("[%s] Max retry count reached for close, giving up", GetId()));
			pendingToClose = false;
			retryCount = 0;
			return;
		}

		if (marketStatus.isClosed) {
			logger.info(StringFormat(
				"[%s] Close pending: Market closed, will retry in %d seconds",
				GetId(),
				marketStatus.opensInSeconds
			));
			retryAfter = currentTime + marketStatus.opensInSeconds;
			return;
		}

		Close();
	}

	void Open() {
		SMarketStatus marketStatus = getMarketStatus(symbol);

		if (marketStatus.isClosed) {
			retryAfter = dtime.Timestamp() + marketStatus.opensInSeconds;
			return;
		}

		if (!ValidateMinimumVolume()) {
			logger.info(StringFormat("[%s] Order cancelled - Volume does not meet minimum requirements", GetId()));
			Cancel();
			return;
		}

		bool isBuy = (side == ORDER_TYPE_BUY);

		MqlTradeResult result = ATrade::Open(
			symbol,
			GetId(),
			isBuy,
			isMarketOrder,
			openAtPrice,
			volume,
			takeProfitPrice,
			stopLossPrice,
			magicNumber
		);

		OnOpen(result);
	}

	void Close() {
		if (status == ORDER_STATUS_OPEN) {
			SMarketStatus marketStatus = getMarketStatus(symbol);

			if (marketStatus.isClosed) {
				pendingToClose = true;
				retryAfter = dtime.Timestamp() + marketStatus.opensInSeconds;
				logger.info(StringFormat(
					"[%s] Close pending: Market closed, will retry in %d seconds",
					GetId(),
					marketStatus.opensInSeconds
				));
				return;
			}

			logger.info(StringFormat(
				"[%s] Closing open position, position_id: %llu",
				GetId(),
				GetPositionId()
			));

			if (!ATrade::Close(GetPositionId())) {
				retryCount++;
				logger.error(StringFormat(
					"[%s] Failed to close open position, retry %d/%d",
					GetId(),
					retryCount,
					MAX_RETRY_COUNT
				));
				return;
			}

			logger.info(StringFormat("[%s] Close order sent to broker, waiting for confirmation...", GetId()));
			status = ORDER_STATUS_CLOSING;
			pendingToClose = false;
			retryCount = 0;
			return;
		}

		if (status == ORDER_STATUS_PENDING) {
			if (GetOrderId() == 0) {
				logger.info(StringFormat("[%s] Cannot cancel order: invalid orderId", GetId()));
				Cancel();
				return;
			}

			if (!OrderSelect(GetOrderId())) {
				logger.info(StringFormat(
					"[%s] Order no longer exists (orderId: %llu), updating status to cancelled",
					GetId(),
					GetOrderId()
				));
				Cancel();
				return;
			}

			if (!ATrade::Cancel(GetOrderId())) {
				logger.error(StringFormat(
					"[%s] Failed to cancel pending order, orderId: %llu",
					GetId(),
					GetOrderId()
				));
				return;
			}

			logger.info(StringFormat("[%s] Cancel order sent to broker, waiting for confirmation...", GetId()));
			status = ORDER_STATUS_CLOSING;
			pendingToOpen = false;
			return;
		}
	}

	void OnOpen(const MqlTradeResult &result) {
		if (result.retcode != 0 && result.retcode != 10009 &&
		    result.retcode != 10010) {
			retryCount++;
			logger.error(StringFormat(
				"[%s] Error opening order: %d, retry %d/%d",
				GetId(),
				result.retcode,
				retryCount,
				MAX_RETRY_COUNT
			));

			if (retryCount >= MAX_RETRY_COUNT)
				Cancel();

			return;
		}

		bool wasPending = (status == ORDER_STATUS_PENDING);
		isProcessed = true;
		pendingToOpen = false;
		retryCount = 0;
		openAt = dtime.Now();
		openPrice = result.price;
		SetDealId(result.deal);
		SetOrderId(result.order);

		if (GetDealId() > 0) {
			HistoryDealSelect(GetDealId());
			SetPositionId(HistoryDealGetInteger(GetDealId(), DEAL_POSITION_ID));
		}

		if (GetDealId() == 0) {
			status = ORDER_STATUS_PENDING;
			logger.info(StringFormat(
				"[%s] Order opened as pending, orderId: %llu",
				GetId(),
				GetOrderId()
			));
		} else {
			if (wasPending) {
				logger.info(StringFormat(
					"[%s] Pending order has opened, dealId: %llu, positionId: %llu",
					GetId(),
					GetDealId(),
					GetPositionId()
				));
			} else {
				logger.info(StringFormat(
					"[%s] Order opened immediately, dealId: %llu, positionId: %llu",
					GetId(),
					GetDealId(),
					GetPositionId()
				));
			}

			status = ORDER_STATUS_OPEN;
		}

		Snapshot();

		if (CheckPointer(persistence) != POINTER_INVALID)
			persistence.SaveOrder(this);
	}

	void OnClose(
		const SDateTime &time,
		double price,
		double profits,
		ENUM_DEAL_REASON reason
	) {
		closeAt = time;
		closePrice = price;
		profitInDollars = profits;
		status = ORDER_STATUS_CLOSED;

		if (profits == 0.0 && price == 0.0) {
			status = ORDER_STATUS_CANCELLED;
			logger.info(StringFormat("[%s] Order cancelled", GetId()));
		}

		orderCloseReason = reason;
		Snapshot();

		if (reason == DEAL_REASON_TP)
			logger.info(StringFormat("[%s] Order closed by Take Profit", GetId()));

		if (reason == DEAL_REASON_EXPERT)
			logger.info(StringFormat("[%s] Order closed by Expert", GetId()));

		if (reason == DEAL_REASON_CLIENT)
			logger.info(StringFormat("[%s] Order closed by Client", GetId()));

		if (reason == DEAL_REASON_MOBILE)
			logger.info(StringFormat("[%s] Order closed by Mobile", GetId()));

		if (reason == DEAL_REASON_WEB)
			logger.info(StringFormat("[%s] Order closed by Web", GetId()));

		if (reason == DEAL_REASON_SL)
			logger.info(StringFormat("[%s] Order closed by Stop Loss", GetId()));

		if (status == ORDER_STATUS_CLOSED)
			if (CheckPointer(persistence) != POINTER_INVALID)
				persistence.DeleteOrder(GetId());
	}

	void OnDeinit() {
		id = "";
		source = "";
		status = ORDER_STATUS_CLOSED;
		isInitialized = false;
		isProcessed = false;
	}

	void Cancel() {
		status = ORDER_STATUS_CANCELLED;
		pendingToOpen = false;
		isProcessed = true;

		if (CheckPointer(persistence) != POINTER_INVALID)
			persistence.DeleteOrder(GetId());
	}

	string GetId() {
		if (id == "")
			RefreshId();

		return id;
	}

	string GetSource() {
		return source;
	}

	string GetSymbol() {
		return symbol;
	}

	ulong GetMagicNumber() {
		return magicNumber;
	}

	ENUM_ORDER_STATUSES GetStatus() {
		return status;
	}

	int GetSide() {
		return side;
	}

	double GetVolume() {
		return volume;
	}

	double GetSignalPrice() {
		return signalPrice;
	}

	double GetOpenAtPrice() {
		return openAtPrice;
	}

	double GetOpenPrice() {
		return openPrice;
	}

	double GetClosePrice() {
		return closePrice;
	}

	double GetProfitInDollars() {
		return profitInDollars;
	}

	double GetFloatingPnL() {
		if (status != ORDER_STATUS_OPEN)
			return 0.0;

		if (GetPositionId() == 0)
			return 0.0;

		if (!PositionSelectByTicket(GetPositionId()))
			return 0.0;

		return PositionGetDouble(POSITION_PROFIT) +
		       PositionGetDouble(POSITION_SWAP);
	}

	SDateTime GetSignalAt() {
		return signalAt;
	}

	SDateTime GetOpenAt() {
		return openAt;
	}

	SSOrderHistory GetSnapshot() {
		return snapshot;
	}

	bool IsMarketOrder() {
		return isMarketOrder;
	}

	bool IsProcessed() {
		return isProcessed;
	}

	bool IsInitialized() {
		return isInitialized;
	}

	bool IsPendingToOpen() {
		return pendingToOpen;
	}

	bool IsPendingToClose() {
		return pendingToClose;
	}

	int GetRetryCount() {
		return retryCount;
	}

	datetime GetRetryAfter() {
		return retryAfter;
	}

	void SetId(string newId) {
		id = newId;
	}

	bool SetTakeProfit(double newTakeProfitPrice = 0) {
		if (newTakeProfitPrice <= 0)
			return false;

		takeProfitPrice = newTakeProfitPrice;

		if (status == ORDER_STATUS_OPEN) {
			if (!ATrade::ModifyTakeProfit(takeProfitPrice, magicNumber)) {
				logger.error(StringFormat("[%s] Failed to modify take profit on open position", GetId()));
				return false;
			}

			logger.info(StringFormat(
				"[%s] Take profit modified to: %.*f",
				GetId(),
				(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
				takeProfitPrice
			));
		}

		return true;
	}

	bool SetStopLoss(double newStopLossPrice = 0) {
		if (newStopLossPrice <= 0)
			return false;

		stopLossPrice = newStopLossPrice;

		if (status == ORDER_STATUS_OPEN) {
			if (!ATrade::ModifyStopLoss(stopLossPrice, magicNumber)) {
				logger.error(StringFormat("[%s] Failed to modify stop loss on open position", GetId()));
				return false;
			}

			logger.info(StringFormat(
				"[%s] Stop loss modified to: %.*f",
				GetId(),
				(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
				stopLossPrice
			));
		}

		return true;
	}

	void SetSource(string newSource) {
		source = newSource;
	}

	void SetSymbol(string newSymbol) {
		symbol = newSymbol;
	}

	void SetMagicNumber(ulong newMagicNumber) {
		magicNumber = newMagicNumber;
	}

	void SetStatus(ENUM_ORDER_STATUSES newStatus) {
		status = newStatus;
	}

	void SetSide(int newSide) {
		side = newSide;
	}

	void SetVolume(double newVolume) {
		volume = newVolume;
	}

	void SetSignalPrice(double newSignalPrice) {
		signalPrice = newSignalPrice;
	}

	void SetOpenAtPrice(double newOpenAtPrice) {
		openAtPrice = newOpenAtPrice;
	}

	void SetOpenPrice(double newOpenPrice) {
		openPrice = newOpenPrice;
	}

	void SetSignalAt(SDateTime &newSignalAt) {
		signalAt = newSignalAt;
	}

	void SetOpenAt(SDateTime &newOpenAt) {
		openAt = newOpenAt;
	}

	void SetIsMarketOrder(bool value) {
		isMarketOrder = value;
	}

	void SetIsProcessed(bool value) {
		isProcessed = value;
	}

	void SetIsInitialized(bool value) {
		isInitialized = value;
	}

	void SetPendingToOpen(bool value) {
		pendingToOpen = value;
	}

	void SetPendingToClose(bool value) {
		pendingToClose = value;
	}

	void SetRetryCount(int value) {
		retryCount = value;
	}

	void SetRetryAfter(datetime value) {
		retryAfter = value;
	}

	void SetPersistence(SEOrderPersistence *value) {
		persistence = value;
	}
};

#endif
