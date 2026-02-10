#ifndef __SS_DB_CONDITION_MQH__
#define __SS_DB_CONDITION_MQH__

#include "../enums/ESeDbOperator.mqh"

struct SSDbCondition {
	string field;
	ENUM_SE_DB_OPERATOR op;
	string stringValue;
	double numberValue;
	bool useStringValue;
};

#endif
