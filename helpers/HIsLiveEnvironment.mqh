#ifndef __H_IS_LIVE_ENVIRONMENT_MQH__
#define __H_IS_LIVE_ENVIRONMENT_MQH__

bool IsLiveEnvironment() {
	return MQLInfoInteger(MQL_TESTER) == false &&
	       MQLInfoInteger(MQL_VISUAL_MODE) == false;
}

#endif
