#ifndef __H_GET_CLOSE_REASON_MQH__
#define __H_GET_CLOSE_REASON_MQH__

string GetCloseReason(ENUM_DEAL_REASON reason) {
	if (reason == DEAL_REASON_TP) {
		return "tp";
	}

	if (reason == DEAL_REASON_SL) {
		return "sl";
	}

	if (reason == DEAL_REASON_EXPERT) {
		return "expert";
	}

	if (reason == DEAL_REASON_CLIENT) {
		return "client";
	}

	if (reason == DEAL_REASON_MOBILE) {
		return "mobile";
	}

	if (reason == DEAL_REASON_WEB) {
		return "web";
	}

	return "unknown";
}

#endif
