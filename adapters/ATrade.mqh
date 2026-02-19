#ifndef __A_TRADE_MQH__
#define __A_TRADE_MQH__

#include <Trade/Trade.mqh>
#include "../services/SELogger/SELogger.mqh"

#define SLIPPAGE_POINTS 5

class ATrade {
private:
	SELogger logger;
	ulong dealId;
	ulong orderId;
	ulong positionId;

	ENUM_ORDER_TYPE_FILLING getFillingMode(string symbol) {
		long fillingModes = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

		if ((fillingModes & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
			return ORDER_FILLING_FOK;
		}

		if ((fillingModes & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
			return ORDER_FILLING_IOC;
		}

		return ORDER_FILLING_RETURN;
	}

public:
	ATrade() {
		logger.SetPrefix("Trade");

		dealId = 0;
		orderId = 0;
		positionId = 0;
	}

	bool Cancel(ulong orderTicket) {
		CTrade trade;
		return trade.OrderDelete(orderTicket);
	}

	bool Close(ulong positionTicket) {
		CTrade trade;
		return trade.PositionClose(positionTicket);
	}

	bool CloseOrCancel(ulong ticket) {
		if (IsPendingOrder(ticket)) {
			logger.Info(StringFormat("Canceling pending order: %llu", ticket));
			return Cancel(ticket);
		}

		if (IsOpenPosition(ticket)) {
			logger.Info(StringFormat("Closing open position: %llu", ticket));
			return Close(ticket);
		}

		logger.Debug(StringFormat("Order/Position not found: %llu", ticket));
		return false;
	}

	bool IsPendingOrder(ulong ticket) {
		return OrderSelect(ticket);
	}

	bool IsOpenPosition(ulong ticket) {
		return PositionSelectByTicket(ticket);
	}

	bool Modify(double price = 0, double stopLoss = 0, double takeProfit = 0,
		    ulong magicNumber = 0) {
		logger.Info(StringFormat("Modifying order, position_id=%d, order_id=%d",
			GetPositionId(), GetOrderId()));

		if (stopLoss == 0 && takeProfit == 0) {
			return false;
		}

		if (!PositionSelectByTicket(GetPositionId())) {
			logger.Error(StringFormat("Error selecting position: %llu", GetPositionId()));
			return false;
		}

		string positionSymbol = PositionGetString(POSITION_SYMBOL);
		double currentSl = PositionGetDouble(POSITION_SL);
		double currentTp = PositionGetDouble(POSITION_TP);
		double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		request.action = TRADE_ACTION_SLTP;
		request.position = GetPositionId();
		request.symbol = positionSymbol;
		request.magic = magicNumber;
		request.price = (price > 0) ? price : openPrice;
		request.sl = (stopLoss > 0) ? NormalizeDouble(stopLoss,
			(int)SymbolInfoInteger(
				positionSymbol,
				SYMBOL_DIGITS)) :
			     currentSl;
		request.tp = (takeProfit > 0) ? NormalizeDouble(takeProfit,
			(int)SymbolInfoInteger(
				positionSymbol,
				SYMBOL_DIGITS)) :
			     currentTp;

		if (!OrderSend(request, result)) {
			logger.Error(StringFormat("Error sending order modification: %d", GetLastError()));
			return false;
		}

		if (result.retcode != TRADE_RETCODE_DONE) {
			logger.Error(StringFormat("Error modifying order: %d", result.retcode));
			return false;
		}

		return true;
	}

	bool ModifyPrice(double price, ulong magicNumber = 0) {
		return Modify(price, 0, 0, magicNumber);
	}

	bool ModifyStopLoss(double stopLoss, ulong magicNumber = 0) {
		return Modify(0, stopLoss, 0, magicNumber);
	}

	bool ModifyTakeProfit(double takeProfit, ulong magicNumber = 0) {
		return Modify(0, 0, takeProfit, magicNumber);
	}

	MqlTradeResult Open(
		string symbol,
		string id,
		bool isBuy,
		bool isMarketOrder,
		double openAtPrice,
		double lot,
		double takeProfit,
		double stopLoss,
		ulong magicNumber) {
		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		double currentPrice = (isBuy) ? SymbolInfoDouble(symbol,
			SYMBOL_ASK) :
				      SymbolInfoDouble(symbol, SYMBOL_BID);
		double minDistance = (double)SymbolInfoInteger(symbol,
			SYMBOL_TRADE_STOPS_LEVEL)
				     * SymbolInfoDouble(symbol, SYMBOL_POINT);
		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

		if (isMarketOrder) {
			request.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
		} else {
			request.type = isBuy ? (openAtPrice <
						currentPrice ? ORDER_TYPE_BUY_LIMIT :
						ORDER_TYPE_BUY_STOP) : (openAtPrice >
									currentPrice ?
									ORDER_TYPE_SELL_LIMIT
	    : ORDER_TYPE_SELL_STOP);

			if (request.type == ORDER_TYPE_BUY_STOP) {
				if (openAtPrice <= ask + minDistance) {
					openAtPrice = ask + minDistance +
						      (5 * SymbolInfoDouble(symbol, SYMBOL_POINT));
				}
			}

			if (request.type == ORDER_TYPE_SELL_STOP) {
				if (openAtPrice >= bid - minDistance) {
					openAtPrice = bid - minDistance -
						      (5 * SymbolInfoDouble(symbol, SYMBOL_POINT));
				}
			}
		}

		request.comment = id;
		request.action =
			(isMarketOrder) ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING;
		request.symbol = symbol;
		request.volume = Volume(symbol, lot);
		request.deviation = SLIPPAGE_POINTS;
		request.magic = magicNumber;
		request.type_filling = getFillingMode(symbol);
		request.price = (isMarketOrder) ? currentPrice : openAtPrice;

		if (stopLoss > 0) {
			request.sl = NormalizeDouble(stopLoss,
				(int)SymbolInfoInteger(symbol,
					SYMBOL_DIGITS));
		}

		if (takeProfit > 0) {
			request.tp = NormalizeDouble(takeProfit,
				(int)SymbolInfoInteger(symbol,
					SYMBOL_DIGITS));
		}

		logger.Separator("Trade request");
		logger.Debug(StringFormat("Comment: %s", request.comment));
		logger.Debug(StringFormat("Action: %s", EnumToString(request.action)));
		logger.Debug(StringFormat("Symbol: %s", request.symbol));
		logger.Debug(StringFormat("Volume: %f", request.volume));
		logger.Debug(StringFormat("Deviation: %d", request.deviation));
		logger.Debug(StringFormat("Magic: %d", request.magic));
		logger.Debug(StringFormat("Type filling: %s",
			EnumToString(request.type_filling)));
		logger.Debug(StringFormat("Price: %f", request.price));
		logger.Debug(StringFormat("Stop loss: %f", request.sl));
		logger.Debug(StringFormat("Take profit: %f", request.tp));

		if (!OrderSend(request, result)) {
			logger.Error(StringFormat("Error opening order: %d", GetLastError()));
			return result;
		}

		SetDealId(result.deal);
		SetOrderId(result.order);

		if (GetDealId() > 0) {
			HistoryDealSelect(GetDealId());
			SetPositionId(HistoryDealGetInteger(GetDealId(), DEAL_POSITION_ID));
			logger.Info(StringFormat("Position ID found: %llu", GetPositionId()));
		}

		logger.Info(StringFormat(
			"Order opened, deal_id=%d, order_id=%d, position_id=%d",
			GetDealId(), GetOrderId(), GetPositionId()));
		return result;
	}

	double Volume(string symbol, double lot) {
		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (lot < minLot) {
			lot = minLot;
		} else {
			lot = MathFloor(lot / lotStep) * lotStep;
		}

		if (lot < minLot) {
			lot = 0;
		}

		if (lot > maxLot) {
			lot = maxLot;
		}

		return NormalizeDouble(lot, 2);
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

	ulong GetDealId() const {
		return dealId;
	}

	ulong GetOrderId() const {
		return orderId;
	}

	ulong GetPositionId() const {
		return positionId;
	}
};

#endif
