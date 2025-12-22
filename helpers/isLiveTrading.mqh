#ifndef __IS_LIVE_TRADING_MQH__
#define __IS_LIVE_TRADING_MQH__

bool isLiveTrading() {
	return MQLInfoInteger(MQL_TESTER) == false &&
	       MQLInfoInteger(MQL_VISUAL_MODE) == false &&
	       AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == true &&
	       TerminalInfoInteger(TERMINAL_CONNECTED) == true;
}

#endif
