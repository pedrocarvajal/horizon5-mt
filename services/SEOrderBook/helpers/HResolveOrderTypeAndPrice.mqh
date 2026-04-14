#ifndef __H_RESOLVE_ORDER_TYPE_AND_PRICE_MQH__
#define __H_RESOLVE_ORDER_TYPE_AND_PRICE_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../helpers/HIsBuySide.mqh"

#include "../structs/SResolvedOrder.mqh"

#include "../../../constants/COTrade.mqh"

double AdjustStopPriceForMinDistance(
	ENUM_ORDER_TYPE orderType,
	double price,
	double ask,
	double bid,
	double minDistance,
	double point
) {
	if (orderType == ORDER_TYPE_BUY_STOP && price <= ask + minDistance) {
		return ask + minDistance + (STOP_DISTANCE_BUFFER_POINTS * point);
	}

	if (orderType == ORDER_TYPE_SELL_STOP && price >= bid - minDistance) {
		return bid - minDistance - (STOP_DISTANCE_BUFFER_POINTS * point);
	}

	return price;
}

SResolvedOrder ResolveOrderTypeAndPrice(EOrder &order, string symbol) {
	SResolvedOrder resolved;
	bool isBuy = IsBuySide((ENUM_ORDER_TYPE)order.GetSide());

	if (order.IsMarketOrder()) {
		resolved.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
		resolved.price = isBuy
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);
		return resolved;
	}

	double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
	double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
	double minDistance = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
	double currentPrice = isBuy ? ask : bid;
	double openAtPrice = order.GetOpenAtPrice();

	if (isBuy) {
		resolved.type = (openAtPrice < currentPrice) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
	} else {
		resolved.type = (openAtPrice > currentPrice) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
	}

	resolved.price = AdjustStopPriceForMinDistance(resolved.type, openAtPrice, ask, bid, minDistance, point);
	return resolved;
}

#endif
