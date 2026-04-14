#ifndef __SE_FILE_DB_DLL_MQH__
#define __SE_FILE_DB_DLL_MQH__

#import "HorizonFileDb.dll"
int FdbInit(const string basePath);

int FdbDatabaseCreate(const string databasePath);

int FdbCollectionGet(int databaseId, const string collectionName);
void FdbCollectionSetAutoFlush(int collectionId, int enabled);
int FdbCollectionCount(int collectionId);
int FdbCollectionFlush(int collectionId);
int FdbCollectionLoad(int collectionId);
int FdbCollectionDeleteFile(int collectionId);

int FdbInsertOne(int collectionId, const string jsonDocument);
int FdbUpdateOne(int collectionId, const string key, const string value, const string jsonPatch);
int FdbDeleteOne(int collectionId, const string key, const string value);

int FdbFindOne(int collectionId, const string key, const string value);
int FdbFindOneResultSize();
void FdbFindOneGetResult(string &buffer, int bufferSize);

int FdbQueryCreate();
void FdbQueryDestroy(int queryId);
void FdbQueryWhereEquals(int queryId, const string field, const string value);
void FdbQueryWhereEqualsNumber(int queryId, const string field, double value);

int FdbFind(int collectionId, int queryId);
int FdbFindResultSize(int index);
void FdbFindGetResult(int index, string &buffer, int bufferSize);

int FdbCollectionSerializeAll(int collectionId);
void FdbCollectionSerializeAllGetResult(string &buffer, int bufferSize);
#import

#endif
