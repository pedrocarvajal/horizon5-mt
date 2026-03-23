#ifndef HORIZON_FDB_QUERY_ENGINE_H
#define HORIZON_FDB_QUERY_ENGINE_H

#include "../constants/Limits.h"
#include "../entities/Document.h"
#include "../entities/Query.h"

#include <rapidjson/document.h>

#include <string>
#include <cstring>

class QueryEngine {
public:
    static bool Matches(const FdbDocument* doc, const FdbQuery& query)
    {
        if (doc == nullptr) {
            return false;
        }

        for (const auto& condition : query.conditions) {
            if (!EvaluateCondition(doc->dom, condition)) {
                return false;
            }
        }

        return true;
    }

private:
    static bool EvaluateCondition(const rapidjson::Document& dom, const FdbCondition& condition)
    {
        const char* field = condition.field.c_str();

        if (!dom.HasMember(field)) {
            return false;
        }

        const auto& member = dom[field];

        if (condition.useStringComparison) {
            if (!member.IsString()) {
                return false;
            }

            std::string documentValue = member.GetString();
            const std::string& conditionValue = condition.stringValue;

            switch (condition.op) {
            case FDB_OP_EQUALS:
                return documentValue == conditionValue;
            case FDB_OP_NOT_EQUALS:
                return documentValue != conditionValue;
            case FDB_OP_CONTAINS:
                return documentValue.find(conditionValue) != std::string::npos;
            default:
                return false;
            }
        }

        double documentValue = 0.0;

        if (member.IsNumber()) {
            documentValue = member.GetDouble();
        } else {
            return false;
        }

        switch (condition.op) {
        case FDB_OP_EQUALS:
            return documentValue == condition.numberValue;
        case FDB_OP_NOT_EQUALS:
            return documentValue != condition.numberValue;
        case FDB_OP_GREATER_THAN:
            return documentValue > condition.numberValue;
        case FDB_OP_LESS_THAN:
            return documentValue < condition.numberValue;
        case FDB_OP_GREATER_THAN_OR_EQUAL:
            return documentValue >= condition.numberValue;
        case FDB_OP_LESS_THAN_OR_EQUAL:
            return documentValue <= condition.numberValue;
        default:
            return false;
        }
    }
};

#endif
