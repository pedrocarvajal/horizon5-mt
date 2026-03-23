#ifndef __H_IS_LIVE_TRADING_MQH__
#define __H_IS_LIVE_TRADING_MQH__

#include "../entities/EAccount.mqh"

bool IsLiveTrading() {
	EAccount localAccount;
	return MQLInfoInteger(MQL_TESTER) == false &&
	       MQLInfoInteger(MQL_VISUAL_MODE) == false &&
	       localAccount.IsTradeAllowed() &&
	       TerminalInfoInteger(TERMINAL_CONNECTED) == true;
}

bool IsLiveEnvironment() {
	return MQLInfoInteger(MQL_TESTER) == false &&
	       MQLInfoInteger(MQL_VISUAL_MODE) == false;
}

#endif
