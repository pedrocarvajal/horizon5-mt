#ifndef __H_GET_SAFE_MARGIN_LEVEL_MQH__
#define __H_GET_SAFE_MARGIN_LEVEL_MQH__

double GetSafeMarginLevel() {
	if (AccountInfoDouble(ACCOUNT_MARGIN) > 0) {
		return NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2);
	}

	return 0.0;
}

#endif
