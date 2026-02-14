#ifndef __H_IS_LIVE_TRADING_MQH__
#define __H_IS_LIVE_TRADING_MQH__

bool IsLiveTrading() {
	return MQLInfoInteger(MQL_TESTER) == false &&
	       MQLInfoInteger(MQL_VISUAL_MODE) == false &&
	       AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == true &&
	       TerminalInfoInteger(TERMINAL_CONNECTED) == true;
}

#endif
