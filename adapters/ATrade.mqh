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

		return false;
	}

	bool IsPendingOrder(ulong ticket) {
		return OrderSelect(ticket);
	}

	bool IsOpenPosition(ulong ticket) {
		return PositionSelectByTicket(ticket);
	}

	bool Modify(double stopLoss = 0, double takeProfit = 0,
		    ulong magicNumber = 0) {
		logger.Info(StringFormat("Modifying order, position_id=%llu, order_id=%llu",
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

		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		request.action = TRADE_ACTION_SLTP;
		request.position = GetPositionId();
		request.symbol = positionSymbol;
		request.magic = magicNumber;
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

	bool ModifyStopLoss(double stopLoss, ulong magicNumber = 0) {
		return Modify(stopLoss, 0, magicNumber);
	}

	bool ModifyTakeProfit(double takeProfit, ulong magicNumber = 0) {
		return Modify(0, takeProfit, magicNumber);
	}

	bool ModifyStopLossAndTakeProfit(double stopLoss, double takeProfit, ulong magicNumber = 0) {
		return Modify(stopLoss, takeProfit, magicNumber);
	}

	MqlTradeResult Open(
		string symbol,
		string id,
		ENUM_ORDER_TYPE orderType,
		double price,
		double volume,
		double takeProfit,
		double stopLoss,
		ulong magicNumber) {
		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
		bool isMarketOrder = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL);

		request.action = isMarketOrder ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING;
		request.type = orderType;
		request.comment = id;
		request.symbol = symbol;
		request.volume = volume;
		request.deviation = SLIPPAGE_POINTS;
		request.magic = magicNumber;
		request.type_filling = getFillingMode(symbol);
		request.price = NormalizeDouble(price, digits);

		if (stopLoss > 0) {
			request.sl = NormalizeDouble(stopLoss, digits);
		}

		if (takeProfit > 0) {
			request.tp = NormalizeDouble(takeProfit, digits);
		}

		logger.Separator("Trade request");

		if (!OrderSend(request, result)) {
			logger.Error(StringFormat("Error opening order: %s (%d)",
				DescribeRetcode(result.retcode), GetLastError()));
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
			"Order opened, deal_id=%llu, order_id=%llu, position_id=%llu",
			GetDealId(), GetOrderId(), GetPositionId()));
		return result;
	}

	static string DescribeRetcode(uint retcode) {
		switch (retcode) {
		case TRADE_RETCODE_REQUOTE: return "Requote";
		case TRADE_RETCODE_REJECT: return "Request rejected";
		case TRADE_RETCODE_CANCEL: return "Request canceled by trader";
		case TRADE_RETCODE_PLACED: return "Order placed";
		case TRADE_RETCODE_DONE: return "Request completed";
		case TRADE_RETCODE_DONE_PARTIAL: return "Partially completed";
		case TRADE_RETCODE_ERROR: return "Request processing error";
		case TRADE_RETCODE_TIMEOUT: return "Request timeout";
		case TRADE_RETCODE_INVALID: return "Invalid request";
		case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
		case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
		case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops (SL/TP)";
		case TRADE_RETCODE_TRADE_DISABLED: return "Trade disabled";
		case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
		case TRADE_RETCODE_NO_MONEY: return "Insufficient funds";
		case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
		case TRADE_RETCODE_PRICE_OFF: return "No quotes for processing";
		case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
		case TRADE_RETCODE_ORDER_CHANGED: return "Order state changed";
		case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
		case TRADE_RETCODE_NO_CHANGES: return "No changes in request";
		case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
		case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client";
		case TRADE_RETCODE_LOCKED: return "Request locked for processing";
		case TRADE_RETCODE_FROZEN: return "Order/position frozen";
		case TRADE_RETCODE_INVALID_FILL: return "Invalid fill type";
		case TRADE_RETCODE_CONNECTION: return "No connection to server";
		case TRADE_RETCODE_ONLY_REAL: return "Only real accounts allowed";
		case TRADE_RETCODE_LIMIT_ORDERS: return "Order limit reached";
		case TRADE_RETCODE_LIMIT_VOLUME: return "Volume limit reached";
		case TRADE_RETCODE_INVALID_ORDER: return "Invalid or prohibited order type";
		case TRADE_RETCODE_POSITION_CLOSED: return "Position already closed";
		default: return StringFormat("Unknown retcode (%d)", retcode);
		}
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
