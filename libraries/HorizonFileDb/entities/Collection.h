#ifndef HORIZON_FDB_COLLECTION_H
#define HORIZON_FDB_COLLECTION_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "../constants/Limits.h"
#include "Document.h"

#include <string>
#include <vector>
#include <unordered_map>

struct FdbCollection {
    std::wstring name;
    std::wstring filePath;
    int databaseId;
    bool autoFlush;
    bool active;

    std::vector<FdbDocument*> documents;
    std::unordered_map<std::string, int> idIndex;
    CRITICAL_SECTION lock;

    FdbCollection()
        : databaseId(-1)
        , autoFlush(true)
        , active(false)
    {
    }

    ~FdbCollection()
    {
        ClearDocuments();
    }

    void ClearDocuments()
    {
        for (auto* doc : documents) {
            delete doc;
        }
        documents.clear();
        idIndex.clear();
    }

    void AddDocument(FdbDocument* doc)
    {
        int index = static_cast<int>(documents.size());
        documents.push_back(doc);

        if (!doc->cachedId.empty()) {
            idIndex[doc->cachedId] = index;
        }
    }

    int FindByKeyValue(const char* key, const char* value) const
    {
        std::string keyStr(key);
        std::string valStr(value);

        if (keyStr == "_id") {
            auto it = idIndex.find(valStr);
            if (it != idIndex.end()) {
                return it->second;
            }
            return -1;
        }

        for (int i = 0; i < static_cast<int>(documents.size()); i++) {
            const auto& dom = documents[i]->dom;
            if (dom.HasMember(key) && dom[key].IsString()) {
                if (valStr == dom[key].GetString()) {
                    return i;
                }
            }
        }

        return -1;
    }

    void RemoveAtIndex(int index)
    {
        if (index < 0 || index >= static_cast<int>(documents.size())) {
            return;
        }

        std::string removedId = documents[index]->cachedId;
        delete documents[index];

        int lastIndex = static_cast<int>(documents.size()) - 1;

        if (index != lastIndex) {
            documents[index] = documents[lastIndex];

            if (!documents[index]->cachedId.empty()) {
                idIndex[documents[index]->cachedId] = index;
            }
        }

        documents.pop_back();

        if (!removedId.empty()) {
            idIndex.erase(removedId);
        }
    }
};

#endif
