#ifndef __H_IS_DUPLICATE_ID_MQH__
#define __H_IS_DUPLICATE_ID_MQH__

bool SEGateway::isDuplicateId(const string &addedIds[], const string orderId) {
	for (int i = 0; i < ArraySize(addedIds); i++) {
		if (addedIds[i] == orderId) {
			return true;
		}
	}

	return false;
}

#endif
