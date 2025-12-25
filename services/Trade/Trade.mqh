#ifndef __TRADE_SERVICE_MQH__
#define __TRADE_SERVICE_MQH__

class Trade
{
private:
	Logger logger;

public:
	ulong deal_id;
	ulong order_id;
	ulong position_id;

	Trade() {
		logger.SetPrefix("Trade");
	}

	MqlTradeResult Open(
		string symbol,
		string id,
		bool is_buy,
		bool is_market_order,
		double open_at_price,
		double lot,
		double take_profit,
		double stop_loss,
		ulong magic_number
		) {
		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		double current_price = (is_buy) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
		double min_distance = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);
		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

		if (is_market_order) {
			request.type = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
		} else {
			request.type = is_buy ? (open_at_price < current_price ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP) : (open_at_price > current_price ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP);

			if (request.type == ORDER_TYPE_BUY_STOP)
				if (open_at_price <= ask + min_distance)
					open_at_price = ask + min_distance + (5 * SymbolInfoDouble(symbol, SYMBOL_POINT));

			if (request.type == ORDER_TYPE_SELL_STOP)
				if (open_at_price >= bid - min_distance)
					open_at_price = bid - min_distance - (5 * SymbolInfoDouble(symbol, SYMBOL_POINT));
		}

		request.comment = id;
		request.action = (is_market_order) ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING;
		request.symbol = symbol;
		request.volume = Volume(symbol, lot);
		request.deviation = 5;
		request.magic = magic_number;
		request.type_filling = filling_mode;
		request.price = (is_market_order) ? current_price : open_at_price;

		if (stop_loss > 0)
			request.sl = NormalizeDouble(stop_loss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

		if (take_profit > 0)
			request.tp = NormalizeDouble(take_profit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

		logger.separator("Trade request");
		logger.debug(StringFormat("Comment: %s", request.comment));
		logger.debug(StringFormat("Action: %s", request.action));
		logger.debug(StringFormat("Symbol: %s", request.symbol));
		logger.debug(StringFormat("Volume: %f", request.volume));
		logger.debug(StringFormat("Deviation: %d", request.deviation));
		logger.debug(StringFormat("Magic: %d", request.magic));
		logger.debug(StringFormat("Type filling: %s", request.type_filling));
		logger.debug(StringFormat("Price: %f", request.price));
		logger.debug(StringFormat("Stop loss: %f", request.sl));
		logger.debug(StringFormat("Take profit: %f", request.tp));

		if (!OrderSend(request, result)) {
			logger.error("Error opening order: " + IntegerToString(GetLastError()));
			return result;
		} else {
			deal_id = result.deal;
			order_id = result.order;

			if (deal_id > 0) {
				HistoryDealSelect(deal_id);
				position_id = HistoryDealGetInteger(deal_id, DEAL_POSITION_ID);
				logger.info("Position ID found: " + IntegerToString(position_id));
			}

			logger.info("Order opened, deal_id=" + IntegerToString(deal_id) + ", order_id=" + IntegerToString(order_id) + ", position_id=" + IntegerToString(position_id));
			return result;
		}
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

	bool Cancel(ulong order_ticket) {
		CTrade trade;
		return trade.OrderDelete(order_ticket);
	}

	bool Close(ulong position_ticket) {
		CTrade trade;
		return trade.PositionClose(position_ticket);
	}

	bool CloseOrCancel(ulong ticket) {
		if (IsPendingOrder(ticket)) {
			logger.info("Canceling pending order: " + IntegerToString(ticket));
			return Cancel(ticket);
		} else if (IsOpenPosition(ticket)) {
			logger.info("Closing open position: " + IntegerToString(ticket));
			return Close(ticket);
		} else {
			logger.debug("Order/Position not found: " + IntegerToString(ticket));
			return false;
		}
	}

	bool Modify(double price = 0, double stop_loss = 0, double take_profit = 0, ulong magic_number = 0) {
		logger.info("Modifying order, position_id=" + IntegerToString(position_id) + ", order_id=" + IntegerToString(order_id));

		if (stop_loss == 0 && take_profit == 0)
			return false;

		if (!PositionSelectByTicket(position_id)) {
			logger.error("Error selecting position: " + IntegerToString(position_id));
			return false;
		}

		string position_symbol = PositionGetString(POSITION_SYMBOL);
		double current_sl = PositionGetDouble(POSITION_SL);
		double current_tp = PositionGetDouble(POSITION_TP);
		double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
		double min_distance = (double)SymbolInfoInteger(position_symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(position_symbol, SYMBOL_POINT);
		double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(position_symbol, SYMBOL_BID) : SymbolInfoDouble(position_symbol, SYMBOL_ASK);

		MqlTradeRequest request;
		MqlTradeResult result;
		ZeroMemory(request);
		ZeroMemory(result);

		request.action = TRADE_ACTION_SLTP;
		request.position = position_id;
		request.symbol = position_symbol;
		request.magic = magic_number;

		request.price = (price > 0) ? price : open_price;

		request.sl = (stop_loss > 0) ? NormalizeDouble(stop_loss, (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS)) : current_sl;
		request.tp = (take_profit > 0) ? NormalizeDouble(take_profit, (int)SymbolInfoInteger(position_symbol, SYMBOL_DIGITS)) : current_tp;

		if (OrderSend(request, result)) {
			if (result.retcode == TRADE_RETCODE_DONE) {
				return true;
			} else {
				logger.error("Error modifying order: " + IntegerToString(result.retcode));
				return false;
			}
		} else {
			logger.error("Error sending order modification: " + IntegerToString(GetLastError()));
			return false;
		}
	}

	bool ModifyStopLoss(double stop_loss, ulong magic_number = 0) {
		return Modify(0, stop_loss, 0, magic_number);
	}

	bool ModifyTakeProfit(double take_profit, ulong magic_number = 0) {
		return Modify(0, 0, take_profit, magic_number);
	}

	bool ModifyPrice(double price, ulong magic_number = 0) {
		return Modify(price, 0, 0, magic_number);
	}

	double Volume(string symbol, double lot) {
		double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (lot < min_lot)
			lot = min_lot;
		else
			lot = MathFloor(lot / lot_step) * lot_step;

		if (lot < min_lot)
			lot = 0;

		if (lot > max_lot)
			lot = max_lot;

		return NormalizeDouble(lot, 2);
	}



	bool ClosePosition(ulong position_ticket) {
		return Close(position_ticket);
	}

	bool CancelOrder(ulong order_ticket) {
		return Cancel(order_ticket);
	}
};

#endif
