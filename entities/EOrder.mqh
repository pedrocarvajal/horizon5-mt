#ifndef __E_ORDER_MQH__
#define __E_ORDER_MQH__

#include "../enums/EOrderStatuses.mqh"
#include "../structs/SSOrderHistory.mqh"

#include "../helpers/HGenerateUuid.mqh"

#include "../services/SEDateTime/SEDateTime.mqh"
#include "../services/SEDateTime/structs/SDateTime.mqh"
#include "../services/SELogger/SELogger.mqh"

class SRPersistenceOfOrders;

class EOrder {
private:
	ulong dealId;
	ulong orderId;
	ulong positionId;
	SRPersistenceOfOrders *persistence;
	SELogger logger;

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
	double commission;
	double swap;
	double grossProfit;

	SDateTime signalAt;
	SDateTime openAt;
	SDateTime closeAt;

	SSOrderHistory snapshot;

public:
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
		source = "";

		status = ORDER_STATUS_PENDING;
		side = ORDER_TYPE_BUY;
		orderCloseReason = (ENUM_DEAL_REASON)0;

		volume = 0;
		signalPrice = 0;
		openAtPrice = 0;
		openPrice = 0;
		closePrice = 0;
		profitInDollars = 0;
		takeProfitPrice = 0;
		stopLossPrice = 0;
		commission = 0;
		swap = 0;
		grossProfit = 0;

		dealId = 0;
		orderId = 0;
		positionId = 0;
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
		commission = other.commission;
		swap = other.swap;
		grossProfit = other.grossProfit;

		snapshot = other.snapshot;

		dealId = other.dealId;
		orderId = other.orderId;
		positionId = other.positionId;
	}

	void OnInit() {
		if (isInitialized) {
			logger.Info(StringFormat("[%s] Order already initialized", GetId()));
			return;
		}

		isInitialized = true;
	}

	void OnDeinit() {
		persistence = NULL;

		isInitialized = false;
		isProcessed = false;
		isMarketOrder = false;
		pendingToOpen = false;
		pendingToClose = false;
		retryCount = 0;
		retryAfter = 0;
		id = "";
		source = "";

		status = ORDER_STATUS_CLOSED;
		side = ORDER_TYPE_BUY;
		orderCloseReason = (ENUM_DEAL_REASON)0;

		volume = 0;
		signalPrice = 0;
		openAtPrice = 0;
		openPrice = 0;
		closePrice = 0;
		profitInDollars = 0;
		takeProfitPrice = 0;
		stopLossPrice = 0;
		commission = 0;
		swap = 0;
		grossProfit = 0;

		dealId = 0;
		orderId = 0;
		positionId = 0;
	}

	void BuildSnapshot() {
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

	string GetId() {
		if (id == "") {
			refreshId();
		}

		return id;
	}

	string GetSource() const {
		return source;
	}

	string GetSymbol() const {
		return symbol;
	}

	ulong GetMagicNumber() const {
		return magicNumber;
	}

	ENUM_ORDER_STATUSES GetStatus() const {
		return status;
	}

	ENUM_DEAL_REASON GetCloseReason() const {
		return orderCloseReason;
	}

	int GetSide() const {
		return side;
	}

	double GetVolume() const {
		return volume;
	}

	double GetSignalPrice() const {
		return signalPrice;
	}

	double GetOpenAtPrice() const {
		return openAtPrice;
	}

	double GetOpenPrice() const {
		return openPrice;
	}

	double GetClosePrice() const {
		return closePrice;
	}

	double GetTakeProfitPrice() const {
		return takeProfitPrice;
	}

	double GetStopLossPrice() const {
		return stopLossPrice;
	}

	double GetProfitInDollars() const {
		return profitInDollars;
	}

	double GetCommission() const {
		return commission;
	}

	double GetSwap() const {
		return swap;
	}

	double GetGrossProfit() const {
		return grossProfit;
	}

	double GetFloatingPnL() const {
		if (status != ORDER_STATUS_OPEN) {
			return 0.0;
		}

		if (GetPositionId() == 0) {
			return 0.0;
		}

		if (!PositionSelectByTicket(GetPositionId())) {
			return 0.0;
		}

		return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
	}

	SDateTime GetSignalAt() const {
		return signalAt;
	}

	SDateTime GetOpenAt() const {
		return openAt;
	}

	SDateTime GetCloseAt() const {
		return closeAt;
	}

	SSOrderHistory GetSnapshot() const {
		return snapshot;
	}

	bool IsMarketOrder() const {
		return isMarketOrder;
	}

	bool IsProcessed() const {
		return isProcessed;
	}

	bool IsInitialized() const {
		return isInitialized;
	}

	bool IsPendingToOpen() const {
		return pendingToOpen;
	}

	bool IsPendingToClose() const {
		return pendingToClose;
	}

	int GetRetryCount() const {
		return retryCount;
	}

	datetime GetRetryAfter() const {
		return retryAfter;
	}

	ulong GetDealId() const {
		return dealId;
	}

	ulong GetOrderId() const {
		return orderId;
	}

	ulong GetPositionId() const {
		return positionId;
	}

	SRPersistenceOfOrders * GetPersistence() const {
		return persistence;
	}

	void SetId(string newId) {
		id = newId;
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

	void SetClosePrice(double newClosePrice) {
		closePrice = newClosePrice;
	}

	void SetProfitInDollars(double newProfitInDollars) {
		profitInDollars = newProfitInDollars;
	}

	void SetCloseReason(ENUM_DEAL_REASON newCloseReason) {
		orderCloseReason = newCloseReason;
	}

	void SetStopLossPrice(double newStopLossPrice) {
		stopLossPrice = newStopLossPrice;
	}

	void SetTakeProfitPrice(double newTakeProfitPrice) {
		takeProfitPrice = newTakeProfitPrice;
	}

	void SetSignalAt(const SDateTime &newSignalAt) {
		signalAt = newSignalAt;
	}

	void SetOpenAt(const SDateTime &newOpenAt) {
		openAt = newOpenAt;
	}

	void SetCloseAt(const SDateTime &newCloseAt) {
		closeAt = newCloseAt;
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

	void SetCommission(double value) {
		commission = value;
	}

	void SetSwap(double value) {
		swap = value;
	}

	void SetGrossProfit(double value) {
		grossProfit = value;
	}

	void SetPersistence(SRPersistenceOfOrders *value) {
		persistence = value;
	}

	void SetDealId(ulong newDealId) {
		dealId = newDealId;
	}

	void SetOrderId(ulong newOrderId) {
		orderId = newOrderId;
	}

	void SetPositionId(ulong newPositionId) {
		positionId = newPositionId;
	}

private:
	void refreshId() {
		id = GenerateUuid();
	}
};

#endif
