#ifndef __H_BUILD_ORDER_COMMENT_MQH__
#define __H_BUILD_ORDER_COMMENT_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../constants/COOrder.mqh"

string BuildOrderComment(EOrder &order, string symbol) {
	string cleanSymbol = symbol;
	StringReplace(cleanSymbol, ".", "");

	string orderId = order.GetId();
	StringReplace(orderId, "-", "");
	string shortId = StringSubstr(orderId, 0, ORDER_COMMENT_SHORT_ID_LENGTH);

	string comment = ORDER_COMMENT_PREFIX + cleanSymbol + order.GetSource() + shortId;
	StringToUpper(comment);

	return comment;
}

#endif
