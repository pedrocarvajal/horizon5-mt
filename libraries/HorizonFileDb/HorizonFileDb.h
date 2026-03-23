#ifndef HORIZON_FILE_DB_H
#define HORIZON_FILE_DB_H

#ifdef HORIZON_FDB_EXPORTS
#define FDB_API __declspec(dllexport)
#else
#define FDB_API __declspec(dllimport)
#endif

extern "C" {

FDB_API int __stdcall FdbInit(const wchar_t* basePath);
FDB_API void __stdcall FdbShutdown();

FDB_API int __stdcall FdbDatabaseCreate(const wchar_t* databasePath);
FDB_API void __stdcall FdbDatabaseDrop(int databaseId);

FDB_API int __stdcall FdbCollectionGet(int databaseId, const wchar_t* collectionName);
FDB_API void __stdcall FdbCollectionSetAutoFlush(int collectionId, int enabled);
FDB_API int __stdcall FdbCollectionCount(int collectionId);
FDB_API int __stdcall FdbCollectionFlush(int collectionId);
FDB_API int __stdcall FdbCollectionLoad(int collectionId);
FDB_API int __stdcall FdbCollectionDrop(int collectionId);
FDB_API int __stdcall FdbCollectionDeleteFile(int collectionId);

FDB_API int __stdcall FdbInsertOne(int collectionId, const wchar_t* jsonDocument);
FDB_API int __stdcall FdbUpdateOne(int collectionId, const wchar_t* key, const wchar_t* value, const wchar_t* jsonPatch);
FDB_API int __stdcall FdbDeleteOne(int collectionId, const wchar_t* key, const wchar_t* value);

FDB_API int __stdcall FdbFindOne(int collectionId, const wchar_t* key, const wchar_t* value);
FDB_API int __stdcall FdbFindOneResultSize();
FDB_API void __stdcall FdbFindOneGetResult(wchar_t* buffer, int bufferSize);

FDB_API int __stdcall FdbQueryCreate();
FDB_API void __stdcall FdbQueryReset(int queryId);
FDB_API void __stdcall FdbQueryDestroy(int queryId);
FDB_API void __stdcall FdbQueryWhereEquals(int queryId, const wchar_t* field, const wchar_t* value);
FDB_API void __stdcall FdbQueryWhereEqualsNumber(int queryId, const wchar_t* field, double value);
FDB_API void __stdcall FdbQueryWhereNotEquals(int queryId, const wchar_t* field, const wchar_t* value);
FDB_API void __stdcall FdbQueryWhereNotEqualsNumber(int queryId, const wchar_t* field, double value);
FDB_API void __stdcall FdbQueryWhereContains(int queryId, const wchar_t* field, const wchar_t* value);
FDB_API void __stdcall FdbQueryWhereGreaterThan(int queryId, const wchar_t* field, double value);
FDB_API void __stdcall FdbQueryWhereGreaterThanOrEqual(int queryId, const wchar_t* field, double value);
FDB_API void __stdcall FdbQueryWhereLessThan(int queryId, const wchar_t* field, double value);
FDB_API void __stdcall FdbQueryWhereLessThanOrEqual(int queryId, const wchar_t* field, double value);

FDB_API int __stdcall FdbFind(int collectionId, int queryId);
FDB_API int __stdcall FdbFindResultCount();
FDB_API int __stdcall FdbFindResultSize(int index);
FDB_API void __stdcall FdbFindGetResult(int index, wchar_t* buffer, int bufferSize);

FDB_API int __stdcall FdbCollectionSerializeAll(int collectionId);
FDB_API void __stdcall FdbCollectionSerializeAllGetResult(wchar_t* buffer, int bufferSize);

FDB_API void __stdcall FdbGetLastError(wchar_t* buffer, int bufferSize);

}

#endif
