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

	void Reset() {
		if (queryHandle != -1) {
			FdbQueryReset(queryHandle);
		}
	}

	SEDbQuery *WhereContains(string field, string value) {
		if (queryHandle != -1) {
			FdbQueryWhereContains(queryHandle, field, value);
		}
		return &this;
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

	SEDbQuery *WhereGreaterThan(string field, double value) {
		if (queryHandle != -1) {
			FdbQueryWhereGreaterThan(queryHandle, field, value);
		}
		return &this;
	}

	SEDbQuery *WhereGreaterThanOrEqual(string field, double value) {
		if (queryHandle != -1) {
			FdbQueryWhereGreaterThanOrEqual(queryHandle, field, value);
		}
		return &this;
	}

	SEDbQuery *WhereLessThan(string field, double value) {
		if (queryHandle != -1) {
			FdbQueryWhereLessThan(queryHandle, field, value);
		}
		return &this;
	}

	SEDbQuery *WhereLessThanOrEqual(string field, double value) {
		if (queryHandle != -1) {
			FdbQueryWhereLessThanOrEqual(queryHandle, field, value);
		}
		return &this;
	}

	SEDbQuery *WhereNotEquals(string field, string value) {
		if (queryHandle != -1) {
			FdbQueryWhereNotEquals(queryHandle, field, value);
		}
		return &this;
	}

	SEDbQuery *WhereNotEquals(string field, double value) {
		if (queryHandle != -1) {
			FdbQueryWhereNotEqualsNumber(queryHandle, field, value);
		}
		return &this;
	}
};

#endif
