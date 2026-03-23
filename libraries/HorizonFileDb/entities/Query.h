#ifndef HORIZON_FDB_QUERY_H
#define HORIZON_FDB_QUERY_H

#include <string>
#include <vector>

enum FdbOperator {
    FDB_OP_EQUALS,
    FDB_OP_NOT_EQUALS,
    FDB_OP_GREATER_THAN,
    FDB_OP_LESS_THAN,
    FDB_OP_GREATER_THAN_OR_EQUAL,
    FDB_OP_LESS_THAN_OR_EQUAL,
    FDB_OP_CONTAINS
};

struct FdbCondition {
    std::string field;
    FdbOperator op;
    std::string stringValue;
    double numberValue;
    bool useStringComparison;

    FdbCondition()
        : op(FDB_OP_EQUALS)
        , numberValue(0.0)
        , useStringComparison(true)
    {
    }
};

struct FdbQuery {
    std::vector<FdbCondition> conditions;
    bool active;

    FdbQuery()
        : active(false)
    {
    }

    void Reset()
    {
        conditions.clear();
    }

    void AddStringCondition(const char* field, FdbOperator op, const char* value)
    {
        FdbCondition condition;
        condition.field = field;
        condition.op = op;
        condition.stringValue = value;
        condition.numberValue = 0.0;
        condition.useStringComparison = true;
        conditions.push_back(condition);
    }

    void AddNumberCondition(const char* field, FdbOperator op, double value)
    {
        FdbCondition condition;
        condition.field = field;
        condition.op = op;
        condition.stringValue = "";
        condition.numberValue = value;
        condition.useStringComparison = false;
        conditions.push_back(condition);
    }
};

#endif
