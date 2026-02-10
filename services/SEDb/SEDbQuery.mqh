#ifndef __SE_DB_QUERY_MQH__
#define __SE_DB_QUERY_MQH__

#include "../../libraries/json/index.mqh"
#include "structs/SSDbCondition.mqh"

class SEDbQuery {
private:
	SSDbCondition conditions[];

public:
	SEDbQuery() {
	}

	int GetConditionCount() {
		return ArraySize(conditions);
	}

	bool Matches(JSON::Object *document) {
		if (document == NULL)
			return false;

		int size = ArraySize(conditions);
		for (int i = 0; i < size; i++)
			if (!evaluateCondition(document, conditions[i]))
				return false;

		return true;
	}

	void Reset() {
		ArrayResize(conditions, 0);
	}

	SEDbQuery *WhereContains(string field, string value) {
		return addCondition(field, SE_DB_OP_CONTAINS, value);
	}

	SEDbQuery *WhereEquals(string field, string value) {
		return addCondition(field, SE_DB_OP_EQUALS, value);
	}

	SEDbQuery *WhereEquals(string field, double value) {
		return addCondition(field, SE_DB_OP_EQUALS, value);
	}

	SEDbQuery *WhereGreaterThan(string field, double value) {
		return addCondition(field, SE_DB_OP_GREATER_THAN, value);
	}

	SEDbQuery *WhereGreaterThanOrEqual(string field, double value) {
		return addCondition(field, SE_DB_OP_GREATER_THAN_OR_EQUAL, value);
	}

	SEDbQuery *WhereLessThan(string field, double value) {
		return addCondition(field, SE_DB_OP_LESS_THAN, value);
	}

	SEDbQuery *WhereLessThanOrEqual(string field, double value) {
		return addCondition(field, SE_DB_OP_LESS_THAN_OR_EQUAL, value);
	}

	SEDbQuery *WhereNotEquals(string field, string value) {
		return addCondition(field, SE_DB_OP_NOT_EQUALS, value);
	}

	SEDbQuery *WhereNotEquals(string field, double value) {
		return addCondition(field, SE_DB_OP_NOT_EQUALS, value);
	}

private:
	SEDbQuery *addCondition(string field, ENUM_SE_DB_OPERATOR op, string value) {
		int size = ArraySize(conditions);

		ArrayResize(conditions, size + 1);
		conditions[size].field = field;
		conditions[size].op = op;
		conditions[size].stringValue = value;
		conditions[size].numberValue = 0;
		conditions[size].useStringValue = true;

		return &this;
	}

	SEDbQuery *addCondition(string field, ENUM_SE_DB_OPERATOR op, double value) {
		int size = ArraySize(conditions);

		ArrayResize(conditions, size + 1);
		conditions[size].field = field;
		conditions[size].op = op;
		conditions[size].stringValue = "";
		conditions[size].numberValue = value;
		conditions[size].useStringValue = false;

		return &this;
	}

	bool evaluateCondition(JSON::Object *document, const SSDbCondition &condition) {
		if (!document.hasValue(condition.field))
			return false;

		if (condition.useStringValue) {
			string documentValue = document.getString(condition.field);

			if (condition.op == SE_DB_OP_EQUALS)
				return documentValue == condition.stringValue;

			if (condition.op == SE_DB_OP_NOT_EQUALS)
				return documentValue != condition.stringValue;

			if (condition.op == SE_DB_OP_CONTAINS)
				return StringFind(documentValue, condition.stringValue) != -1;

			return false;
		}

		double documentValue = document.getNumber(condition.field);

		if (condition.op == SE_DB_OP_EQUALS)
			return documentValue == condition.numberValue;

		if (condition.op == SE_DB_OP_NOT_EQUALS)
			return documentValue != condition.numberValue;

		if (condition.op == SE_DB_OP_GREATER_THAN)
			return documentValue > condition.numberValue;

		if (condition.op == SE_DB_OP_LESS_THAN)
			return documentValue < condition.numberValue;

		if (condition.op == SE_DB_OP_GREATER_THAN_OR_EQUAL)
			return documentValue >= condition.numberValue;

		if (condition.op == SE_DB_OP_LESS_THAN_OR_EQUAL)
			return documentValue <= condition.numberValue;

		return false;
	}
};

#endif
