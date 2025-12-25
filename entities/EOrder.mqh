#ifndef __E_ORDER_MQH__
#define __E_ORDER_MQH__

#include "../enums/EOrderStatuses.mqh"
#include "../structs/SSOrderHistory.mqh"
#include "../adapters/ATrade.mqh"
#include "../services/SEDateTime/SEDateTime.mqh"

class SEOrderPersistence;
class SEReportOfOrderHistory;

extern SEDateTime dtime;
extern SEOrderPersistence *orderPersistence;
extern SEReportOfOrderHistory *orderHistoryReporter;

class EOrder:
public ATrade {
public:
	bool isInitialized;
	bool isProcessed;
	bool isMarketOrder;

	string id;
	string source;
	string sourceCustomId;
	string symbol;
	ulong magicNumber;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON orderCloseReason;

	int layer;
	double volume;

	double signalPrice;
	double openAtPrice;
	double openPrice;
	double closePrice;

	MqlDateTime signalAt;
	MqlDateTime openAt;
	MqlDateTime closeAt;

	double profitInDollars;
	double profitAccumulativeInDollars;

	double mainTakeProfitInPoints;
	double mainStopLossInPoints;

	double mainTakeProfitAtPrice;
	double mainStopLossAtPrice;

	SSOrderHistory snapshot;
	SELogger logger;

public:
	EOrder(ulong strategyMagicNumber = 0, string strategySymbol = "") {
		isInitialized = false;
		isProcessed = false;
		isMarketOrder = false;
		logger.SetPrefix("Order");

		id = "";
		sourceCustomId = "";
		symbol = strategySymbol;
		magicNumber = strategyMagicNumber;
		dealId = 0;
		orderId = 0;
		positionId = 0;
	}

	EOrder(const EOrder& other) {
		isInitialized = other.isInitialized;
		isProcessed = other.isProcessed;
		isMarketOrder = other.isMarketOrder;
		logger.SetPrefix("Order");
		id = other.id;
		source = other.source;
		sourceCustomId = other.sourceCustomId;
		symbol = other.symbol;
		magicNumber = other.magicNumber;
		status = other.status;
		side = other.side;
		orderCloseReason = other.orderCloseReason;
		layer = other.layer;
		volume = other.volume;

		signalPrice = other.signalPrice;
		openAtPrice = other.openAtPrice;
		openPrice = other.openPrice;
		closePrice = other.closePrice;
		signalAt = other.signalAt;
		openAt = other.openAt;
		closeAt = other.closeAt;
		profitInDollars = other.profitInDollars;
		profitAccumulativeInDollars = other.profitAccumulativeInDollars;

		mainTakeProfitInPoints = other.mainTakeProfitInPoints;
		mainStopLossInPoints = other.mainStopLossInPoints;
		mainTakeProfitAtPrice = other.mainTakeProfitAtPrice;
		mainStopLossAtPrice = other.mainStopLossAtPrice;

		snapshot = other.snapshot;

		dealId = other.dealId;
		orderId = other.orderId;
		positionId = other.positionId;
	}

	void Snapshot() {
		snapshot.openTime = StructToTime(signalAt);
		snapshot.openPrice = signalPrice;
		snapshot.openLot = volume;
		snapshot.orderId = Id();
		snapshot.side = side;
		snapshot.sourceCustomId = sourceCustomId;
		snapshot.magicNumber = magicNumber;
		snapshot.strategyName = source;
		snapshot.strategyPrefix = source;
		snapshot.layer = layer;
		snapshot.status = status;
		snapshot.orderCloseReason = orderCloseReason;
		snapshot.mainTakeProfitInPoints = mainTakeProfitInPoints;
		snapshot.mainStopLossInPoints = mainStopLossInPoints;
		snapshot.mainTakeProfitAtPrice = mainTakeProfitAtPrice;
		snapshot.mainStopLossAtPrice = mainStopLossAtPrice;
		snapshot.signalAt = StructToTime(signalAt);
		snapshot.closeTime = StructToTime(closeAt);
		snapshot.closePrice = closePrice;
		snapshot.profitInDollars = profitInDollars;
	}

	void OnInit() {
		if (isInitialized) {
			logger.info("[" + Id() + "] Order already initialized");
			return;
		}

		isInitialized = true;
	}

	void CheckToOpen() {
		if (isProcessed)
			return;

		logger.info("[" + Id() + "] Opening order, id: " + Id());
		Open();
	}

	void CheckToClose() {
		Close();
	}

	void Close() {
		if (status == ORDER_STATUS_OPEN) {
			logger.info("[" + Id() + "] Closing open position, position_id: " + IntegerToString(positionId));

			if (!ATrade::Close(positionId)) {
				logger.info("[" + Id() + "] Failed to close open position, ticket: " + IntegerToString(positionId));
				return;
			}

			logger.info("[" + Id() + "] Close order sent to broker, waiting for confirmation...");
			status = ORDER_STATUS_CLOSING;
			return;
		}

		if (status == ORDER_STATUS_PENDING) {
			if (orderId == 0) {
				logger.info("[" + Id() + "] Cannot cancel order: invalid orderId");
				status = ORDER_STATUS_CANCELLED;

				if (CheckPointer(orderPersistence) != POINTER_INVALID)
					orderPersistence.DeleteOrderJson(source, Id());

				return;
			}

			if (!OrderSelect(orderId)) {
				logger.info("[" + Id() + "] Order no longer exists (orderId: " + IntegerToString(orderId) + "), updating status to cancelled");
				status = ORDER_STATUS_CANCELLED;

				if (CheckPointer(orderPersistence) != POINTER_INVALID)
					orderPersistence.DeleteOrderJson(source, Id());

				return;
			}

			if (!ATrade::Cancel(orderId)) {
				logger.info("[" + Id() + "] Failed to cancel pending order, orderId: " + IntegerToString(orderId));
				return;
			}

			logger.info("[" + Id() + "] Cancel order sent to broker, waiting for confirmation...");
			status = ORDER_STATUS_CLOSING;
			return;
		}
	}

	void Open() {
		if (!ValidateMinimumVolume()) {
			status = ORDER_STATUS_CANCELLED;
			isProcessed = true;

			logger.info("[" + Id() + "] Order cancelled - Volume does not meet minimum requirements");

			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, Id());

			return;
		}

		bool isBuy = (side == ORDER_TYPE_BUY);
		double takeProfit = CalculateTakeProfit(openAtPrice);
		double stopLoss = CalculateStopLoss(openAtPrice);

		MqlTradeResult result = ATrade::Open(
			symbol,
			Id(),
			isBuy,
			isMarketOrder,
			openAtPrice,
			volume,
			takeProfit,
			stopLoss,
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
		profitAccumulativeInDollars += profits;
		status = ORDER_STATUS_CLOSED;

		if (profits == 0.0 && price == 0.0) {
			status = ORDER_STATUS_CANCELLED;
			logger.info("[" + Id() + "] Order cancelled");
		}

		orderCloseReason = reason;
		Snapshot();

		if (CheckPointer(orderHistoryReporter) != POINTER_INVALID) {
			orderHistoryReporter.AddOrderSnapshot(snapshot);
			logger.info("[" + Id() + "] Order snapshot added to report");
		}

		if (reason == DEAL_REASON_TP)
			logger.info("[" + Id() + "] Order closed by Take Profit");

		if (reason == DEAL_REASON_EXPERT)
			logger.info("[" + Id() + "] Order closed by Expert");

		if (reason == DEAL_REASON_CLIENT)
			logger.info("[" + Id() + "] Order closed by Client");

		if (reason == DEAL_REASON_MOBILE)
			logger.info("[" + Id() + "] Order closed by Mobile");

		if (reason == DEAL_REASON_WEB)
			logger.info("[" + Id() + "] Order closed by Web");

		if (reason == DEAL_REASON_SL)
			logger.info("[" + Id() + "] Order closed by Stop Loss");

		if (status == ORDER_STATUS_CLOSED)
			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, Id());
	}

	void OnOpen(const MqlTradeResult &result) {
		if (result.retcode != 0 && result.retcode != 10009 && result.retcode != 10010) {
			logger.error("Error opening order: " + IntegerToString(result.retcode));

			status = ORDER_STATUS_CANCELLED;
			isProcessed = true;

			if (CheckPointer(orderPersistence) != POINTER_INVALID)
				orderPersistence.DeleteOrderJson(source, Id());

			return;
		}

		bool wasPending = (status == ORDER_STATUS_PENDING);
		isProcessed = true;
		openAt = dtime.Now();
		openPrice = result.price;
		dealId = result.deal;
		orderId = result.order;

		if (dealId > 0) {
			HistoryDealSelect(dealId);
			positionId = HistoryDealGetInteger(dealId, DEAL_POSITION_ID);
		}

		if (dealId == 0) {
			status = ORDER_STATUS_PENDING;
			logger.info("[" + Id() + "] Order opened as pending, orderId: " + IntegerToString(orderId));
		} else {
			if (wasPending)
				logger.info("[" + Id() + "] Pending order has opened, dealId: " + IntegerToString(dealId) + ", positionId: " + IntegerToString(positionId));
			else
				logger.info("[" + Id() + "] Order opened immediately, dealId: " + IntegerToString(dealId) + ", positionId: " + IntegerToString(positionId));

			status = ORDER_STATUS_OPEN;
		}

		Snapshot();

		if (CheckPointer(orderPersistence) != POINTER_INVALID)
			orderPersistence.SaveOrderToJson(this);
	}

	void SetId(string newId) {
		id = newId;
	}

	string Id() {
		if (id == "")
			RefreshId();

		return id;
	}

	void RefreshId() {
		string uuid = "";
		for (int i = 0; i < 8; i++)
			uuid += IntegerToString(MathRand() % 10);
		id = source + "_" + IntegerToString(layer) + "_" + uuid;
	}

	double CalculateTakeProfit(double price) {
		if (mainTakeProfitAtPrice > 0)
			return mainTakeProfitAtPrice;

		if (mainTakeProfitInPoints == 0)
			return 0;

		return (side == ORDER_TYPE_BUY)
			? price + (mainTakeProfitInPoints * SymbolInfoDouble(symbol, SYMBOL_POINT))
			: price - (mainTakeProfitInPoints * SymbolInfoDouble(symbol, SYMBOL_POINT));
	}

	double CalculateStopLoss(double price) {
		if (mainStopLossAtPrice > 0)
			return mainStopLossAtPrice;

		if (mainStopLossInPoints == 0)
			return 0;

		return (side == ORDER_TYPE_BUY)
			? price - (mainStopLossInPoints * SymbolInfoDouble(symbol, SYMBOL_POINT))
			: price + (mainStopLossInPoints * SymbolInfoDouble(symbol, SYMBOL_POINT));
	}

	bool ValidateMinimumVolume() {
		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (volume <= 0) {
			logger.info("[" + Id() + "] Validation failed - Volume is zero or negative: " + DoubleToString(volume, 5));
			return false;
		}

		if (volume < minLot) {
			logger.info("[" + Id() + "] Validation failed - Volume " + DoubleToString(volume, 5) + " is below minimum lot size: " + DoubleToString(minLot, 5));
			return false;
		}

		if (volume > maxLot) {
			logger.info("[" + Id() + "] Validation failed - Volume " + DoubleToString(volume, 5) + " exceeds maximum lot size: " + DoubleToString(maxLot, 5));
			return false;
		}

		double normalizedVolume = MathFloor(volume / lotStep) * lotStep;
		if (normalizedVolume < minLot) {
			logger.info("[" + Id() + "] Validation failed - Normalized volume " + DoubleToString(normalizedVolume, 5) + " is below minimum after lot step adjustment");
			return false;
		}

		return true;
	}

	void OnDeinit() {
		id = "";
		source = "";
		sourceCustomId = "";
		status = ORDER_STATUS_CLOSED;
		isInitialized = false;
		isProcessed = false;
	}
};

#endif
