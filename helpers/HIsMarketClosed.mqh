#ifndef __H_IS_MARKET_CLOSED_MQH__
#define __H_IS_MARKET_CLOSED_MQH__

#include "./HGetMarketStatus.mqh"

bool IsMarketClosed(string checkSymbol, int safetyMarginMinutes = 1) {
	return GetMarketStatus(checkSymbol, safetyMarginMinutes).isClosed;
}

#endif
