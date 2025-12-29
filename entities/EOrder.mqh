#ifndef __E_ORDER_MQH__
#define __E_ORDER_MQH__

#include "../enums/EOrderStatuses.mqh"
#include "../structs/SSOrderHistory.mqh"
#include "../structs/SQueuedOrder.mqh"
#include "../adapters/ATrade.mqh"
#include "../services/SEDateTime/SEDateTime.mqh"
#include "../helpers/HIsMarketClosed.mqh"

class SEOrderPersistence;
class SEReportOfOrderHistory;

extern SEDateTime dtime;
extern SEOrderPersistence *orderPersistence;
extern SEReportOfOrderHistory *orderHistoryReporter;
extern SQueuedOrder queuedOrders[];

class EOrder:
public ATrade {
private:
	bool isInitialized;
	bool isProcessed;
	bool isMarketOrder;
	bool allowQueueing;

	string id;
	string source;
	string symbol;
	ulong magicNumber;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON orderCloseReason;

	double volume;

	double signalPrice;
	double openAtPrice;
	double openPrice;
	double closePrice;

	MqlDateTime signalAt;
	MqlDateTime openAt;
	MqlDateTime closeAt;

	double profitInDollars;

	double mainTakeProfitAtPrice;
	double mainStopLossAtPrice;

	SSOrderHistory snapshot;
	SELogger logger;

public:
	EOrder(ulong strategyMagicNumber = 0, string strategySymbol = "") {
		logger.SetPrefix("Order");

		symbol = strategySymbol;
		magicNumber = strategyMagicNumber;

		isInitialized = false;
		isProcessed = false;
		isMarketOrder = false;
		allowQueueing = false;
		id = "";
		SetDealId(0);
		SetOrderId(0);
		SetPositionId(0);
	}

	EOrder(const EOrder& other) {
		logger.SetPrefix("Order");

		isInitialized = other.isInitialized;
		isProcessed = other.isProcessed;
		isMarketOrder = other.isMarketOrder;
		allowQueueing = other.allowQueueing;

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

		mainTakeProfitAtPrice = other.mainTakeProfitAtPrice;
		mainStopLossAtPrice = other.mainStopLossAtPrice;

		snapshot = other.snapshot;

		SetDealId(other.GetDealId());
		SetOrderId(other.GetOrderId());
		SetPositionId(other.GetPositionId());
	}

	void Snapshot() {
		snapshot.openTime = StructToTime(signalAt);
		snapshot.openPrice = signalPrice;
		snapshot.openLot = volume;
		snapshot.orderId = GetId();
		snapshot.side = side;
		snapshot.magicNumber = magicNumber;
		snapshot.strategyName = source;
		snapshot.strategyPrefix = source;
		snapshot.status = status;
		snapshot.orderCloseReason = orderCloseReason;
		snapshot.mainTakeProfitAtPrice = mainTakeProfitAtPrice;
		snapshot.mainStopLossAtPrice = mainStopLossAtPrice;
		snapshot.signalAt = StructToTime(signalAt);
		snapshot.closeTime = StructToTime(closeAt);
		snapshot.closePrice = closePrice;
		snapshot.profitInDollars = profitInDollars;
	}

	void OnInit() {
		if (isInitialized) {
			logger.info("[" + GetId() + "] Order already initialized");
			return;
		}

		isInitialized = true;
	}

	void CheckToOpen() {
		if (isProcessed)
			return;

		logger.info("[" + GetId() + "] Opening order, id: " + GetId());
		Open();
	}

	void CheckToClose() {
		Close();
	}

	void Close() {
		if (status == ORDER_STATUS_OPEN) {
			if (isMarketClosed(symbol)) {
				int size = ArraySize(queuedOrders);
				ArrayResize(queuedOrders, size + 1);

				queuedOrders[size].action = QUEUE_ACTION_CLOSE;
				queuedOrders[size].positionId = GetPositionId();

				logger.info("[" + GetId() + "] Close queued: Market is closed, will execute when market opens");
				return;
			}

			logger.info("[" + GetId() + "] Closing open position, position_id: " + IntegerToString(GetPositionId()));

			if (!ATrade::Close(GetPositionId())) {
				logger.error("[" + GetId() + "] Failed to close open position, ticket: " + IntegerToString(GetPositionId()));
				return;
			}

			logger.info("[" + GetId() + "] Close order sent to broker, waiting for confirmation...");
			status = ORDER_STATUS_CLOSING;
			return;
		}

		if (status == ORDER_STATUS_PENDING) {
			if (GetOrderId() == 0) {
				logger.info("[" + GetId() + "] Cannot cancel order: invalid orderId");
				status = ORDER_STATUS_CANCELLED;

				if (CheckPointer(orderPersistence) != POINTER_INVALID)
					orderPersistence.DeleteOrderJson(source, GetId());

				return;
			}

			if (!OrderSelect(GetOrderId())) {
				logger.info("[" + GetId() + "] Order no longer exists (orderId: " + IntegerToString(GetOrderId()) + "), updating status to cancelled");
				status = ORDER_STATUS_CANCELLED;

				if (CheckPointer(orderPersistence) != POINTER_INVALID)
					orderPersistence.DeleteOrderJson(source, GetId());

				return;
			}

			if (!ATrade::Cancel(GetOrderId())) {
				logger.error("[" + GetId() + "] Failed to cancel pending order, orderId: " + IntegerToString(GetOrderId()));
				return;
			}

			logger.info("[" + GetId() + "] Cancel order sent to broker, waiting for confirmation...");
			status = ORDER_STATUS_CLOSING;
			return;
		}
	}

	void Open() {
		if (isMarketClosed(symbol)) {
			if (allowQueueing)
				return;

			status = ORDER_STATUS_CANCELLED;
			isProcessed = true;

			logger.warning("[" + GetId() + "] Open blocked: Market is closed");

			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, GetId());

			return;
		}

		if (!ValidateMinimumVolume()) {
			status = ORDER_STATUS_CANCELLED;
			isProcessed = true;

			logger.info("[" + GetId() + "] Order cancelled - Volume does not meet minimum requirements");

			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, GetId());

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
			mainTakeProfitAtPrice,
			mainStopLossAtPrice,
			magicNumber
			);

		OnOpen(result);
	}

	void OnClose(
		const MqlDateTime &time,
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
			logger.info("[" + GetId() + "] Order cancelled");
		}

		orderCloseReason = reason;
		Snapshot();

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
			orderHistoryReporter.AddOrderSnapshot(snapshot);
			logger.info("[" + GetId() + "] Order snapshot added to report");
		}

		if (reason == DEAL_REASON_TP)
			logger.info("[" + GetId() + "] Order closed by Take Profit");

		if (reason == DEAL_REASON_EXPERT)
			logger.info("[" + GetId() + "] Order closed by Expert");

		if (reason == DEAL_REASON_CLIENT)
			logger.info("[" + GetId() + "] Order closed by Client");

		if (reason == DEAL_REASON_MOBILE)
			logger.info("[" + GetId() + "] Order closed by Mobile");

		if (reason == DEAL_REASON_WEB)
			logger.info("[" + GetId() + "] Order closed by Web");

		if (reason == DEAL_REASON_SL)
			logger.info("[" + GetId() + "] Order closed by Stop Loss");

		if (status == ORDER_STATUS_CLOSED)
			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, GetId());
	}

	void OnOpen(const MqlTradeResult &result) {
		if (result.retcode != 0 && result.retcode != 10009 && result.retcode != 10010) {
			logger.error("Error opening order: " + IntegerToString(result.retcode));

			status = ORDER_STATUS_CANCELLED;
			isProcessed = true;

			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, GetId());

			return;
		}

		bool wasPending = (status == ORDER_STATUS_PENDING);
		isProcessed = true;
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
			logger.info("[" + GetId() + "] Order opened as pending, orderId: " + IntegerToString(GetOrderId()));
		} else {
			if (wasPending)
				logger.info("[" + GetId() + "] Pending order has opened, dealId: " + IntegerToString(GetDealId()) + ", positionId: " + IntegerToString(GetPositionId()));
			else
				logger.info("[" + GetId() + "] Order opened immediately, dealId: " + IntegerToString(GetDealId()) + ", positionId: " + IntegerToString(GetPositionId()));

			status = ORDER_STATUS_OPEN;
		}

		Snapshot();

		if (CheckPointer(orderPersistence) != POINTER_INVALID)
			orderPersistence.SaveOrderToJson(this);
	}

	void SetId(string newId) {
		id = newId;
	}

	bool SetTakeProfit(double takeProfitAtPrice = 0) {
		if (takeProfitAtPrice <= 0)
			return false;

		mainTakeProfitAtPrice = takeProfitAtPrice;

		if (status == ORDER_STATUS_OPEN) {
			if (!ATrade::ModifyTakeProfit(takeProfitAtPrice, magicNumber)) {
				logger.error("[" + GetId() + "] Failed to modify take profit on open position");
				return false;
			}

			logger.info("[" + GetId() + "] Take profit modified to: " + DoubleToString(takeProfitAtPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
		}

		return true;
	}

	bool SetStopLoss(double stopLossAtPrice = 0) {
		if (stopLossAtPrice <= 0)
			return false;

		mainStopLossAtPrice = stopLossAtPrice;

		if (status == ORDER_STATUS_OPEN) {
			if (!ATrade::ModifyStopLoss(stopLossAtPrice, magicNumber)) {
				logger.error("[" + GetId() + "] Failed to modify stop loss on open position");
				return false;
			}

			logger.info("[" + GetId() + "] Stop loss modified to: " + DoubleToString(stopLossAtPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
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

	void SetSignalAt(MqlDateTime &newSignalAt) {
		signalAt = newSignalAt;
	}

	void SetOpenAt(MqlDateTime &newOpenAt) {
		openAt = newOpenAt;
	}

	void SetIsMarketOrder(bool value) {
		isMarketOrder = value;
	}

	void SetAllowQueueing(bool value) {
		allowQueueing = value;
	}

	void SetIsProcessed(bool value) {
		isProcessed = value;
	}

	void SetIsInitialized(bool value) {
		isInitialized = value;
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

	ENUM_DEAL_REASON GetOrderCloseReason() {
		return orderCloseReason;
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

	MqlDateTime GetSignalAt() {
		return signalAt;
	}

	MqlDateTime GetOpenAt() {
		return openAt;
	}

	MqlDateTime GetCloseAt() {
		return closeAt;
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

	bool AllowsQueueing() {
		return allowQueueing;
	}

	void RefreshId() {
		string uuid = "";
		for (int i = 0; i < 8; i++)
			uuid += IntegerToString(MathRand() % 10);
		id = source + "_" + uuid;
	}

	bool ValidateMinimumVolume() {
		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (volume <= 0) {
			logger.info("[" + GetId() + "] Validation failed - Volume is zero or negative: " + DoubleToString(volume, 5));
			return false;
		}

		if (volume < minLot) {
			logger.info("[" + GetId() + "] Validation failed - Volume " + DoubleToString(volume, 5) + " is below minimum lot size: " + DoubleToString(minLot, 5));
			return false;
		}

		if (volume > maxLot) {
			logger.info("[" + GetId() + "] Validation failed - Volume " + DoubleToString(volume, 5) + " exceeds maximum lot size: " + DoubleToString(maxLot, 5));
			return false;
		}

		double normalizedVolume = MathFloor(volume / lotStep) * lotStep;
		if (normalizedVolume < minLot) {
			logger.info("[" + GetId() + "] Validation failed - Normalized volume " + DoubleToString(normalizedVolume, 5) + " is below minimum after lot step adjustment");
			return false;
		}

		return true;
	}

	void OnDeinit() {
		id = "";
		source = "";
		status = ORDER_STATUS_CLOSED;
		isInitialized = false;
		isProcessed = false;
	}
};

#endif
