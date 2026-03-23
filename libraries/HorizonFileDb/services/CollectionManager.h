#ifndef HORIZON_FDB_COLLECTION_MANAGER_H
#define HORIZON_FDB_COLLECTION_MANAGER_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "../constants/Limits.h"
#include "../entities/Collection.h"
#include "../entities/Query.h"
#include "DatabaseManager.h"
#include "QueryEngine.h"
#include "UuidGenerator.h"
#include "FileIO.h"

#include <rapidjson/document.h>
#include <rapidjson/writer.h>
#include <rapidjson/stringbuffer.h>

#include <string>
#include <algorithm>

class CollectionManager {
private:
    FdbCollection collections[FDB_MAX_COLLECTIONS];
    int collectionCount;
    CRITICAL_SECTION registryLock;
    DatabaseManager* databaseManager;

public:
    CollectionManager(DatabaseManager* dbManager)
        : collectionCount(0)
        , databaseManager(dbManager)
    {
        InitializeCriticalSection(&registryLock);
    }

    ~CollectionManager()
    {
        Shutdown();
        DeleteCriticalSection(&registryLock);
    }

    int GetOrCreateCollection(int databaseId, const wchar_t* collectionName)
    {
        EnterCriticalSection(&registryLock);

        for (int i = 0; i < collectionCount; i++) {
            if (collections[i].active &&
                collections[i].databaseId == databaseId &&
                collections[i].name == collectionName) {
                LeaveCriticalSection(&registryLock);
                return i;
            }
        }

        if (collectionCount >= FDB_MAX_COLLECTIONS) {
            LeaveCriticalSection(&registryLock);
            return -1;
        }

        FdbDatabase* db = databaseManager->GetDatabase(databaseId);
        if (db == nullptr) {
            LeaveCriticalSection(&registryLock);
            return -1;
        }

        int index = collectionCount;
        collections[index].name = collectionName;
        collections[index].databaseId = databaseId;
        collections[index].autoFlush = true;
        collections[index].active = true;
        InitializeCriticalSection(&collections[index].lock);

        std::wstring dbPath = db->path;
        std::wstring basePath = databaseManager->GetBasePath();

        std::replace(dbPath.begin(), dbPath.end(), L'/', L'\\');

        collections[index].filePath = basePath + L"\\" + dbPath + L"\\" + collectionName + L".json";

        db->collectionIds.push_back(index);
        collectionCount++;

        LeaveCriticalSection(&registryLock);
        return index;
    }

    void SetAutoFlush(int collectionId, bool enabled)
    {
        if (!IsValidCollection(collectionId)) return;

        EnterCriticalSection(&collections[collectionId].lock);
        collections[collectionId].autoFlush = enabled;
        LeaveCriticalSection(&collections[collectionId].lock);
    }

    int Count(int collectionId)
    {
        if (!IsValidCollection(collectionId)) return 0;

        EnterCriticalSection(&collections[collectionId].lock);
        int count = static_cast<int>(collections[collectionId].documents.size());
        LeaveCriticalSection(&collections[collectionId].lock);

        return count;
    }

    bool Load(int collectionId)
    {
        if (!IsValidCollection(collectionId)) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        std::string fileContent;
        if (!FileIO::ReadFile(col.filePath, fileContent)) {
            LeaveCriticalSection(&col.lock);
            return false;
        }

        if (fileContent.empty()) {
            LeaveCriticalSection(&col.lock);
            return true;
        }

        rapidjson::Document arrayDoc;
        arrayDoc.Parse(fileContent.c_str());

        if (arrayDoc.HasParseError() || !arrayDoc.IsArray()) {
            LeaveCriticalSection(&col.lock);
            return false;
        }

        col.ClearDocuments();
        col.documents.reserve(arrayDoc.Size());

        for (rapidjson::SizeType i = 0; i < arrayDoc.Size(); i++) {
            if (!arrayDoc[i].IsObject()) continue;

            rapidjson::StringBuffer buffer;
            rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
            arrayDoc[i].Accept(writer);

            FdbDocument* doc = new FdbDocument();
            if (doc->ParseFromUtf8(buffer.GetString())) {
                col.AddDocument(doc);
            } else {
                delete doc;
            }
        }

        LeaveCriticalSection(&col.lock);
        return true;
    }

    bool Flush(int collectionId)
    {
        if (!IsValidCollection(collectionId)) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        rapidjson::StringBuffer buffer;
        buffer.Reserve(FDB_FLUSH_BUFFER_INITIAL_SIZE);
        rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);

        writer.StartArray();
        for (const auto* doc : col.documents) {
            if (doc != nullptr) {
                doc->SerializeToBuffer(writer);
            }
        }
        writer.EndArray();

        bool success = FileIO::WriteFile(col.filePath, buffer.GetString(), buffer.GetSize());

        LeaveCriticalSection(&col.lock);
        return success;
    }

    bool InsertOne(int collectionId, const char* jsonUtf8)
    {
        if (!IsValidCollection(collectionId) || jsonUtf8 == nullptr) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        FdbDocument* doc = new FdbDocument();
        if (!doc->ParseFromUtf8(jsonUtf8)) {
            delete doc;
            LeaveCriticalSection(&col.lock);
            return false;
        }

        if (doc->cachedId.empty()) {
            std::string uuid = UuidGenerator::Generate();
            rapidjson::Value idValue;
            idValue.SetString(uuid.c_str(), static_cast<rapidjson::SizeType>(uuid.size()), doc->dom.GetAllocator());
            doc->dom.AddMember(
                rapidjson::Value("_id", doc->dom.GetAllocator()),
                idValue,
                doc->dom.GetAllocator());
            doc->cachedId = uuid;
        }

        col.AddDocument(doc);

        bool shouldFlush = col.autoFlush;
        LeaveCriticalSection(&col.lock);

        if (shouldFlush) {
            Flush(collectionId);
        }

        return true;
    }

    int FindOne(int collectionId, const char* key, const char* value, std::string& resultJson)
    {
        if (!IsValidCollection(collectionId)) return 0;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        int index = col.FindByKeyValue(key, value);
        if (index == -1) {
            LeaveCriticalSection(&col.lock);
            return 0;
        }

        resultJson = col.documents[index]->Serialize();

        LeaveCriticalSection(&col.lock);
        return 1;
    }

    int Find(int collectionId, FdbQuery& query, std::vector<std::string>& results)
    {
        if (!IsValidCollection(collectionId)) return 0;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        results.clear();

        for (const auto* doc : col.documents) {
            if (doc != nullptr && QueryEngine::Matches(doc, query)) {
                results.push_back(doc->Serialize());
            }
        }

        LeaveCriticalSection(&col.lock);
        return static_cast<int>(results.size());
    }

    std::string SerializeAll(int collectionId)
    {
        if (!IsValidCollection(collectionId)) return "[]";

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        rapidjson::StringBuffer buffer;
        buffer.Reserve(FDB_FLUSH_BUFFER_INITIAL_SIZE);
        rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);

        writer.StartArray();
        for (const auto* doc : col.documents) {
            if (doc != nullptr) {
                doc->SerializeToBuffer(writer);
            }
        }
        writer.EndArray();

        std::string result(buffer.GetString(), buffer.GetSize());
        LeaveCriticalSection(&col.lock);
        return result;
    }

    bool UpdateOne(int collectionId, const char* key, const char* value, const char* patchJsonUtf8)
    {
        if (!IsValidCollection(collectionId) || patchJsonUtf8 == nullptr) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        int index = col.FindByKeyValue(key, value);
        if (index == -1) {
            LeaveCriticalSection(&col.lock);
            return false;
        }

        rapidjson::Document patch;
        patch.Parse(patchJsonUtf8);

        if (patch.HasParseError() || !patch.IsObject()) {
            LeaveCriticalSection(&col.lock);
            return false;
        }

        FdbDocument* doc = col.documents[index];
        auto& allocator = doc->dom.GetAllocator();

        for (auto it = patch.MemberBegin(); it != patch.MemberEnd(); ++it) {
            const char* memberName = it->name.GetString();

            if (doc->dom.HasMember(memberName)) {
                doc->dom[memberName].CopyFrom(it->value, allocator);
            } else {
                rapidjson::Value nameKey(memberName, allocator);
                rapidjson::Value valueCopy(it->value, allocator);
                doc->dom.AddMember(nameKey, valueCopy, allocator);
            }
        }

        if (doc->dom.HasMember("_id") && doc->dom["_id"].IsString()) {
            std::string newId = doc->dom["_id"].GetString();
            if (newId != doc->cachedId) {
                if (!doc->cachedId.empty()) {
                    col.idIndex.erase(doc->cachedId);
                }
                doc->cachedId = newId;
                col.idIndex[newId] = index;
            }
        }

        bool shouldFlush = col.autoFlush;
        LeaveCriticalSection(&col.lock);

        if (shouldFlush) {
            Flush(collectionId);
        }

        return true;
    }

    bool DeleteOne(int collectionId, const char* key, const char* value)
    {
        if (!IsValidCollection(collectionId)) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        int index = col.FindByKeyValue(key, value);
        if (index == -1) {
            LeaveCriticalSection(&col.lock);
            return false;
        }

        col.RemoveAtIndex(index);

        bool shouldFlush = col.autoFlush;
        LeaveCriticalSection(&col.lock);

        if (shouldFlush) {
            Flush(collectionId);
        }

        return true;
    }

    bool DeleteFile(int collectionId)
    {
        if (!IsValidCollection(collectionId)) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        col.ClearDocuments();
        bool success = FileIO::DeleteFileByPath(col.filePath);

        LeaveCriticalSection(&col.lock);
        return success;
    }

    bool DropCollection(int collectionId)
    {
        if (!IsValidCollection(collectionId)) return false;

        FdbCollection& col = collections[collectionId];
        EnterCriticalSection(&col.lock);

        col.ClearDocuments();
        FileIO::DeleteFileByPath(col.filePath);
        col.active = false;

        LeaveCriticalSection(&col.lock);
        DeleteCriticalSection(&col.lock);

        return true;
    }

    void Shutdown()
    {
        EnterCriticalSection(&registryLock);

        for (int i = 0; i < collectionCount; i++) {
            if (collections[i].active) {
                collections[i].ClearDocuments();
                collections[i].active = false;
                DeleteCriticalSection(&collections[i].lock);
            }
        }

        collectionCount = 0;
        LeaveCriticalSection(&registryLock);
    }

private:
    bool IsValidCollection(int collectionId) const
    {
        return collectionId >= 0 &&
               collectionId < collectionCount &&
               collections[collectionId].active;
    }
};

#endif
