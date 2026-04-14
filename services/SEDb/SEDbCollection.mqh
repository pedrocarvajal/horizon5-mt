#ifndef __SE_DB_COLLECTION_MQH__
#define __SE_DB_COLLECTION_MQH__

#include "../../libraries/Json/index.mqh"

#include "../SEMessageBus/SEMessageBus.mqh"

#include "SEFileDbDLL.mqh"

#include "SEDbQuery.mqh"

#include "../../constants/COMessageBus.mqh"
#include "../../constants/COSEDb.mqh"

class SEDbCollection {
private:
	string name;
	int collectionHandle;
	string filePath;
	int fileFlags;

public:
	SEDbCollection() {
		name = "";
		collectionHandle = -1;
		filePath = "";
		fileFlags = FILE_TXT | FILE_ANSI;
	}

	void Initialize(string collectionName, int handle, string dbBasePath, bool useCommonFiles) {
		name = collectionName;
		collectionHandle = handle;
		filePath = StringFormat("%s/%s.json", dbBasePath, collectionName);
		fileFlags = FILE_TXT | FILE_ANSI;

		if (useCommonFiles) {
			fileFlags |= FILE_COMMON;
		}
	}

	string GetName() {
		return name;
	}

	void SetAutoFlush(bool enabled) {
		FdbCollectionSetAutoFlush(collectionHandle, enabled ? 1 : 0);
	}

	bool Load() {
		return FdbCollectionLoad(collectionHandle) == 1;
	}

	bool Flush() {
		if (SEMessageBus::IsActive()) {
			string jsonData = BuildJsonFromDll();

			JSON::Object payload;
			payload.setProperty("filePath", filePath);
			payload.setProperty("fileFlags", fileFlags);
			payload.setProperty("data", jsonData);

			if (SEMessageBus::Send(MB_CHANNEL_PERSISTENCE, "flush", payload)) {
				return true;
			}
		}

		return FdbCollectionFlush(collectionHandle) == 1;
	}

	bool InsertOne(JSON::Object *document) {
		if (document == NULL) {
			return false;
		}

		string documentJson = document.toString();
		return FdbInsertOne(collectionHandle, documentJson) == 1;
	}

	JSON::Object *FindOne(string key, string value) {
		int found = FdbFindOne(collectionHandle, key, value);

		if (found == 0) {
			return NULL;
		}

		int resultSize = FdbFindOneResultSize();
		int bufferSize = MathMax(resultSize, SEDB_RESULT_BUFFER_SIZE);
		string buffer = "";
		StringInit(buffer, bufferSize);
		FdbFindOneGetResult(buffer, bufferSize);

		return new JSON::Object(buffer);
	}

	int Find(SEDbQuery &query, JSON::Object *&results[]) {
		ArrayResize(results, 0);

		int queryHandle = query.GetHandle();
		int count = FdbFind(collectionHandle, queryHandle);

		if (count == 0) {
			return 0;
		}

		ArrayResize(results, count);

		for (int i = 0; i < count; i++) {
			int resultSize = FdbFindResultSize(i);
			int bufferSize = MathMax(resultSize, SEDB_RESULT_BUFFER_SIZE);
			string buffer = "";
			StringInit(buffer, bufferSize);
			FdbFindGetResult(i, buffer, bufferSize);
			results[i] = new JSON::Object(buffer);
		}

		return count;
	}

	bool UpdateOne(string key, string value, JSON::Object *newData) {
		if (newData == NULL) {
			return false;
		}

		string patchJson = newData.toString();
		return FdbUpdateOne(collectionHandle, key, value, patchJson) == 1;
	}

	bool DeleteOne(string key, string value) {
		return FdbDeleteOne(collectionHandle, key, value) == 1;
	}

	int Count() {
		return FdbCollectionCount(collectionHandle);
	}

	bool DeleteFile() {
		return FdbCollectionDeleteFile(collectionHandle) == 1;
	}

private:
	string BuildJsonFromDll() {
		int resultSize = FdbCollectionSerializeAll(collectionHandle);

		if (resultSize <= 2) {
			return "[]";
		}

		string buffer = "";
		StringInit(buffer, resultSize);
		FdbCollectionSerializeAllGetResult(buffer, resultSize);
		return buffer;
	}
};

#endif
