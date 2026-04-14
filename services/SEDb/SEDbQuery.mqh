#ifndef __SE_DB_QUERY_MQH__
#define __SE_DB_QUERY_MQH__

#include "../../libraries/Json/index.mqh"

#include "SEFileDbDLL.mqh"

class SEDbQuery {
private:
	int queryHandle;

public:
	SEDbQuery() {
		queryHandle = FdbQueryCreate();
	}

	~SEDbQuery() {
		if (queryHandle != -1) {
			FdbQueryDestroy(queryHandle);
		}
	}

	int GetHandle() {
		return queryHandle;
	}

	SEDbQuery *WhereEquals(string field, string value) {
		if (queryHandle != -1) {
			FdbQueryWhereEquals(queryHandle, field, value);
		}
		return &this;
	}

	SEDbQuery *WhereEquals(string field, double value) {
		if (queryHandle != -1) {
			FdbQueryWhereEqualsNumber(queryHandle, field, value);
		}
		return &this;
	}
};

#endif
