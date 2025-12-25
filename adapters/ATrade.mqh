#ifndef __A_TRADE_MQH__
#define __A_TRADE_MQH__

#include <Trade/Trade.mqh>
#include "../services/SELogger/SELogger.mqh"

class ATrade
{
private:
	SELogger logger;

	ENUM_ORDER_TYPE_FILLING fillingMode;

public:
	ulong dealId;
	ulong orderId;
	ulong positionId;

	ATrade() {
		logger.SetPrefix("Trade");

		fillingMode = ORDER_FILLING_FOK;

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
			logger.info("Canceling pending order: " + IntegerToString(ticket));
			return Cancel(ticket);
		}

		if (IsOpenPosition(ticket)) {
			logger.info("Closing open position: " + IntegerToString(ticket));
			return Close(ticket);
		}

		logger.debug("Order/Position not found: " + IntegerToString(ticket));
		return false;
	}

	bool IsPendingOrder(ulong ticket) {
		if (OrderSelect(ticket))
			return true;

		return false;
	}

	bool IsOpenPosition(ulong ticket) {
		if (PositionSelectByTicket(ticket))
			return true;

		return false;
	}

	bool Modify(double price = 0, double stopLoss = 0, double takeProfit = 0, ulong magicNumber = 0) {
		logger.info(StringFormat("Modifying order, position_id=%d, order_id=%d", positionId, orderId));

		if (stopLoss == 0 && takeProfit == 0)
			return false;

		if (!PositionSelectByTicket(positionId)) {
			logger.error("Error selecting position: " + IntegerToString(positionId));
			return false;
		}

		string positionSymbol = PositionGetString(POSITION_SYMBOL);
		double currentSl = PositionGetDouble(POSITION_SL);
		double currentTp = PositionGetDouble(POSITION_TP);
		double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
		double minDistance = (double)SymbolInfoInteger(positionSymbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(positionSymbol, SYMBOL_POINT);
		double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(positionSymbol, SYMBOL_BID) : SymbolInfoDouble(positionSymbol, SYMBOL_ASK);

		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		request.action = TRADE_ACTION_SLTP;
		request.position = positionId;
		request.symbol = positionSymbol;
		request.magic = magicNumber;
		request.price = (price > 0) ? price : openPrice;
		request.sl = (stopLoss > 0) ? NormalizeDouble(stopLoss, (int)SymbolInfoInteger(positionSymbol, SYMBOL_DIGITS)) : currentSl;
		request.tp = (takeProfit > 0) ? NormalizeDouble(takeProfit, (int)SymbolInfoInteger(positionSymbol, SYMBOL_DIGITS)) : currentTp;

		if (!OrderSend(request, result)) {
			logger.error("Error sending order modification: " + IntegerToString(GetLastError()));
			return false;
		}

		if (result.retcode != TRADE_RETCODE_DONE) {
			logger.error("Error modifying order: " + IntegerToString(result.retcode));
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

		double currentPrice = (isBuy) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
		double minDistance = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);
		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

		if (isMarketOrder) {
			request.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
		} else {
			request.type = isBuy ? (openAtPrice < currentPrice ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP) : (openAtPrice > currentPrice ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP);

			if (request.type == ORDER_TYPE_BUY_STOP)
				if (openAtPrice <= ask + minDistance)
					openAtPrice = ask + minDistance + (5 * SymbolInfoDouble(symbol, SYMBOL_POINT));

			if (request.type == ORDER_TYPE_SELL_STOP)
				if (openAtPrice >= bid - minDistance)
					openAtPrice = bid - minDistance - (5 * SymbolInfoDouble(symbol, SYMBOL_POINT));
		}

		request.comment = id;
		request.action = (isMarketOrder) ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING;
		request.symbol = symbol;
		request.volume = Volume(symbol, lot);
		request.deviation = 5;
		request.magic = magicNumber;
		request.type_filling = fillingMode;
		request.price = (isMarketOrder) ? currentPrice : openAtPrice;

		if (stopLoss > 0)
			request.sl = NormalizeDouble(stopLoss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

		if (takeProfit > 0)
			request.tp = NormalizeDouble(takeProfit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

		logger.separator("Trade request");
		logger.debug(StringFormat("Comment: %s", request.comment));
		logger.debug(StringFormat("Action: %s", EnumToString(request.action)));
		logger.debug(StringFormat("Symbol: %s", request.symbol));
		logger.debug(StringFormat("Volume: %f", request.volume));
		logger.debug(StringFormat("Deviation: %d", request.deviation));
		logger.debug(StringFormat("Magic: %d", request.magic));
		logger.debug(StringFormat("Type filling: %s", EnumToString(request.type_filling)));
		logger.debug(StringFormat("Price: %f", request.price));
		logger.debug(StringFormat("Stop loss: %f", request.sl));
		logger.debug(StringFormat("Take profit: %f", request.tp));

		if (!OrderSend(request, result)) {
			logger.error("Error opening order: " + IntegerToString(GetLastError()));
			return result;
		}

		dealId = result.deal;
		orderId = result.order;

		if (dealId > 0) {
			HistoryDealSelect(dealId);
			positionId = HistoryDealGetInteger(dealId, DEAL_POSITION_ID);
			logger.info("Position ID found: " + IntegerToString(positionId));
		}

		logger.info(StringFormat("Order opened, deal_id=%d, order_id=%d, position_id=%d", dealId, orderId, positionId));
		return result;
	}

	double Volume(string symbol, double lot) {
		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (lot < minLot)
			lot = minLot;
		else
			lot = MathFloor(lot / lotStep) * lotStep;

		if (lot < minLot)
			lot = 0;

		if (lot > maxLot)
			lot = maxLot;

		return NormalizeDouble(lot, 2);
	}

	ulong GetDealId() {
		return dealId;
	}

	ulong GetOrderId() {
		return orderId;
	}

	ulong GetPositionId() {
		return positionId;
	}
};

#endif
