#ifndef HORIZON_FDB_EXPORTS
#define HORIZON_FDB_EXPORTS
#endif

#include "HorizonFileDb.h"
#include "entities/Query.h"
#include "services/DatabaseManager.h"
#include "services/CollectionManager.h"

#include <string>
#include <vector>
#include <algorithm>

static DatabaseManager* databaseManager = nullptr;
static CollectionManager* collectionManager = nullptr;
static bool initialized = false;

static std::vector<FdbQuery> queries;
static CRITICAL_SECTION queryLock;

thread_local std::string findOneResult;
thread_local std::wstring findOneResultWide;
thread_local std::vector<std::string> findResults;
thread_local std::vector<std::wstring> findResultsWide;
thread_local std::string serializeAllResult;
thread_local std::wstring serializeAllResultWide;
thread_local std::wstring lastError;

static std::string WideToUtf8(const wchar_t* wide)
{
    if (wide == nullptr || wide[0] == L'\0') {
        return "";
    }

    int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
    if (sizeNeeded <= 0) {
        return "";
    }

    std::string result(sizeNeeded - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide, -1, &result[0], sizeNeeded, NULL, NULL);

    return result;
}

static std::wstring Utf8ToWide(const std::string& utf8)
{
    if (utf8.empty()) {
        return L"";
    }

    int sizeNeeded = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, NULL, 0);
    if (sizeNeeded <= 0) {
        return L"";
    }

    std::wstring result(sizeNeeded - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &result[0], sizeNeeded);

    return result;
}

static void CopyToWideBuffer(const std::wstring& source, wchar_t* buffer, int bufferSize)
{
    if (buffer == nullptr || bufferSize <= 0) return;

    int copyLength = (std::min)(static_cast<int>(source.size()), bufferSize - 1);
    wcsncpy_s(buffer, bufferSize, source.c_str(), copyLength);
}

static void SetFdbLastError(const wchar_t* message)
{
    lastError = message;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved)
{
    switch (reason) {
    case DLL_PROCESS_ATTACH:
        DisableThreadLibraryCalls(hModule);
        break;
    case DLL_PROCESS_DETACH:
        if (initialized) {
            delete collectionManager;
            delete databaseManager;
            DeleteCriticalSection(&queryLock);
            collectionManager = nullptr;
            databaseManager = nullptr;
            initialized = false;
        }
        break;
    }

    return TRUE;
}

extern "C" {

FDB_API int __stdcall FdbInit(const wchar_t* basePath)
{
    if (initialized) {
        databaseManager->SetBasePath(basePath);
        return 1;
    }

    databaseManager = new DatabaseManager();
    databaseManager->SetBasePath(basePath);
    collectionManager = new CollectionManager(databaseManager);
    InitializeCriticalSection(&queryLock);
    initialized = true;

    return 1;
}

FDB_API void __stdcall FdbShutdown()
{
    if (!initialized) return;

    collectionManager->Shutdown();
    databaseManager->Shutdown();

    delete collectionManager;
    delete databaseManager;
    DeleteCriticalSection(&queryLock);

    collectionManager = nullptr;
    databaseManager = nullptr;

    for (auto& q : queries) {
        q.active = false;
        q.conditions.clear();
    }
    queries.clear();

    initialized = false;
}

FDB_API int __stdcall FdbDatabaseCreate(const wchar_t* databasePath)
{
    if (!initialized || databasePath == nullptr) return -1;
    return databaseManager->CreateDatabase(databasePath);
}

FDB_API void __stdcall FdbDatabaseDrop(int databaseId)
{
    if (!initialized) return;
    databaseManager->DropDatabase(databaseId);
}

FDB_API int __stdcall FdbCollectionGet(int databaseId, const wchar_t* collectionName)
{
    if (!initialized || collectionName == nullptr) return -1;
    return collectionManager->GetOrCreateCollection(databaseId, collectionName);
}

FDB_API void __stdcall FdbCollectionSetAutoFlush(int collectionId, int enabled)
{
    if (!initialized) return;
    collectionManager->SetAutoFlush(collectionId, enabled != 0);
}

FDB_API int __stdcall FdbCollectionCount(int collectionId)
{
    if (!initialized) return 0;
    return collectionManager->Count(collectionId);
}

FDB_API int __stdcall FdbCollectionFlush(int collectionId)
{
    if (!initialized) return 0;
    return collectionManager->Flush(collectionId) ? 1 : 0;
}

FDB_API int __stdcall FdbCollectionLoad(int collectionId)
{
    if (!initialized) return 0;
    return collectionManager->Load(collectionId) ? 1 : 0;
}

FDB_API int __stdcall FdbCollectionDrop(int collectionId)
{
    if (!initialized) return 0;
    return collectionManager->DropCollection(collectionId) ? 1 : 0;
}

FDB_API int __stdcall FdbCollectionDeleteFile(int collectionId)
{
    if (!initialized) return 0;
    return collectionManager->DeleteFile(collectionId) ? 1 : 0;
}

FDB_API int __stdcall FdbInsertOne(int collectionId, const wchar_t* jsonDocument)
{
    if (!initialized || jsonDocument == nullptr) return 0;

    std::string utf8Json = WideToUtf8(jsonDocument);
    return collectionManager->InsertOne(collectionId, utf8Json.c_str()) ? 1 : 0;
}

FDB_API int __stdcall FdbUpdateOne(int collectionId, const wchar_t* key, const wchar_t* value, const wchar_t* jsonPatch)
{
    if (!initialized || key == nullptr || value == nullptr || jsonPatch == nullptr) return 0;

    std::string utf8Key = WideToUtf8(key);
    std::string utf8Value = WideToUtf8(value);
    std::string utf8Patch = WideToUtf8(jsonPatch);

    return collectionManager->UpdateOne(collectionId, utf8Key.c_str(), utf8Value.c_str(), utf8Patch.c_str()) ? 1 : 0;
}

FDB_API int __stdcall FdbDeleteOne(int collectionId, const wchar_t* key, const wchar_t* value)
{
    if (!initialized || key == nullptr || value == nullptr) return 0;

    std::string utf8Key = WideToUtf8(key);
    std::string utf8Value = WideToUtf8(value);

    return collectionManager->DeleteOne(collectionId, utf8Key.c_str(), utf8Value.c_str()) ? 1 : 0;
}

FDB_API int __stdcall FdbFindOne(int collectionId, const wchar_t* key, const wchar_t* value)
{
    if (!initialized || key == nullptr || value == nullptr) return 0;

    std::string utf8Key = WideToUtf8(key);
    std::string utf8Value = WideToUtf8(value);

    findOneResult.clear();
    findOneResultWide.clear();
    int found = collectionManager->FindOne(collectionId, utf8Key.c_str(), utf8Value.c_str(), findOneResult);

    if (found) {
        findOneResultWide = Utf8ToWide(findOneResult);
    }

    return found;
}

FDB_API int __stdcall FdbFindOneResultSize()
{
    return static_cast<int>(findOneResultWide.size()) + 1;
}

FDB_API void __stdcall FdbFindOneGetResult(wchar_t* buffer, int bufferSize)
{
    CopyToWideBuffer(findOneResultWide, buffer, bufferSize);
}

FDB_API int __stdcall FdbQueryCreate()
{
    EnterCriticalSection(&queryLock);

    int count = static_cast<int>(queries.size());

    for (int i = 0; i < count; i++) {
        if (!queries[i].active) {
            queries[i].active = true;
            queries[i].conditions.clear();
            LeaveCriticalSection(&queryLock);
            return i;
        }
    }

    FdbQuery query;
    query.active = true;

    int index = count;
    queries.push_back(std::move(query));

    LeaveCriticalSection(&queryLock);
    return index;
}

FDB_API void __stdcall FdbQueryReset(int queryId)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].Reset();
}

FDB_API void __stdcall FdbQueryDestroy(int queryId)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size())) return;
    queries[queryId].conditions.clear();
    queries[queryId].active = false;
}

FDB_API void __stdcall FdbQueryWhereEquals(int queryId, const wchar_t* field, const wchar_t* value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddStringCondition(WideToUtf8(field).c_str(), FDB_OP_EQUALS, WideToUtf8(value).c_str());
}

FDB_API void __stdcall FdbQueryWhereEqualsNumber(int queryId, const wchar_t* field, double value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddNumberCondition(WideToUtf8(field).c_str(), FDB_OP_EQUALS, value);
}

FDB_API void __stdcall FdbQueryWhereNotEquals(int queryId, const wchar_t* field, const wchar_t* value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddStringCondition(WideToUtf8(field).c_str(), FDB_OP_NOT_EQUALS, WideToUtf8(value).c_str());
}

FDB_API void __stdcall FdbQueryWhereNotEqualsNumber(int queryId, const wchar_t* field, double value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddNumberCondition(WideToUtf8(field).c_str(), FDB_OP_NOT_EQUALS, value);
}

FDB_API void __stdcall FdbQueryWhereContains(int queryId, const wchar_t* field, const wchar_t* value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddStringCondition(WideToUtf8(field).c_str(), FDB_OP_CONTAINS, WideToUtf8(value).c_str());
}

FDB_API void __stdcall FdbQueryWhereGreaterThan(int queryId, const wchar_t* field, double value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddNumberCondition(WideToUtf8(field).c_str(), FDB_OP_GREATER_THAN, value);
}

FDB_API void __stdcall FdbQueryWhereGreaterThanOrEqual(int queryId, const wchar_t* field, double value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddNumberCondition(WideToUtf8(field).c_str(), FDB_OP_GREATER_THAN_OR_EQUAL, value);
}

FDB_API void __stdcall FdbQueryWhereLessThan(int queryId, const wchar_t* field, double value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddNumberCondition(WideToUtf8(field).c_str(), FDB_OP_LESS_THAN, value);
}

FDB_API void __stdcall FdbQueryWhereLessThanOrEqual(int queryId, const wchar_t* field, double value)
{
    if (queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return;
    queries[queryId].AddNumberCondition(WideToUtf8(field).c_str(), FDB_OP_LESS_THAN_OR_EQUAL, value);
}

FDB_API int __stdcall FdbFind(int collectionId, int queryId)
{
    if (!initialized || queryId < 0 || queryId >= static_cast<int>(queries.size()) || !queries[queryId].active) return 0;

    findResults.clear();
    findResultsWide.clear();
    int count = collectionManager->Find(collectionId, queries[queryId], findResults);

    findResultsWide.resize(count);
    for (int i = 0; i < count; i++) {
        findResultsWide[i] = Utf8ToWide(findResults[i]);
    }

    return count;
}

FDB_API int __stdcall FdbFindResultCount()
{
    return static_cast<int>(findResultsWide.size());
}

FDB_API int __stdcall FdbFindResultSize(int index)
{
    if (index < 0 || index >= static_cast<int>(findResultsWide.size())) return 0;
    return static_cast<int>(findResultsWide[index].size()) + 1;
}

FDB_API void __stdcall FdbFindGetResult(int index, wchar_t* buffer, int bufferSize)
{
    if (index < 0 || index >= static_cast<int>(findResultsWide.size())) return;
    CopyToWideBuffer(findResultsWide[index], buffer, bufferSize);
}

FDB_API int __stdcall FdbCollectionSerializeAll(int collectionId)
{
    if (!initialized) return 0;

    serializeAllResult = collectionManager->SerializeAll(collectionId);
    serializeAllResultWide = Utf8ToWide(serializeAllResult);
    return static_cast<int>(serializeAllResultWide.size()) + 1;
}

FDB_API void __stdcall FdbCollectionSerializeAllGetResult(wchar_t* buffer, int bufferSize)
{
    CopyToWideBuffer(serializeAllResultWide, buffer, bufferSize);
}

FDB_API void __stdcall FdbGetLastError(wchar_t* buffer, int bufferSize)
{
    CopyToWideBuffer(lastError, buffer, bufferSize);
}

}
