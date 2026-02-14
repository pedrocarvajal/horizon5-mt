#ifndef __SE_DB_COLLECTION_MQH__
#define __SE_DB_COLLECTION_MQH__

#include "../../libraries/json/index.mqh"
#include "../../helpers/HGenerateUuid.mqh"
#include "SEDbQuery.mqh"

class SEDbCollection {
private:
	string name;
	string filePath;
	int fileFlags;
	bool shouldAutoFlush;
	JSON::Object *documents[];
	string generateId() {
		return GenerateUuid();
	}

	int findIndexByKeyValue(string key, string value) {
		int size = ArraySize(documents);

		for (int i = 0; i < size; i++) {
			if (documents[i] != NULL && documents[i].hasValue(key))
				if (documents[i].getString(key) == value)
					return i;
		}

		return -1;
	}

	void ensureDirectoryExists() {
		int lastSlash = StringFind(filePath, "/");
		int position = lastSlash;

		while (position != -1) {
			lastSlash = position;
			position = StringFind(filePath, "/", lastSlash + 1);
		}

		if (lastSlash <= 0)
			return;

		string directory = StringSubstr(filePath, 0, lastSlash);
		int commonFlag = (fileFlags & FILE_COMMON) != 0 ? FILE_COMMON : 0;
		FolderCreate(directory, commonFlag);
	}

	void removeAtIndex(int index) {
		int size = ArraySize(documents);

		if (index < 0 || index >= size)
			return;

		if (documents[index] != NULL && CheckPointer(documents[index]) == POINTER_DYNAMIC)
			delete documents[index];

		for (int i = index; i < size - 1; i++) {
			documents[i] = documents[i + 1];
		}

		ArrayResize(documents, size - 1);
	}

public:
	SEDbCollection() {
		name = "";
		filePath = "";
		fileFlags = FILE_TXT | FILE_ANSI;
		shouldAutoFlush = true;
	}

	void Initialize(string collectionName, string basePath, bool useCommonFiles) {
		name = collectionName;
		filePath = StringFormat("%s/%s.json", basePath, collectionName);
		fileFlags = FILE_TXT | FILE_ANSI;

		if (useCommonFiles)
			fileFlags |= FILE_COMMON;
	}

	~SEDbCollection() {
		int size = ArraySize(documents);

		for (int i = 0; i < size; i++) {
			if (documents[i] != NULL && CheckPointer(documents[i]) == POINTER_DYNAMIC)
				delete documents[i];
		}

		ArrayResize(documents, 0);
	}

	string GetName() {
		return name;
	}

	void SetAutoFlush(bool enabled) {
		shouldAutoFlush = enabled;
	}

	bool Load() {
		int handle = FileOpen(filePath, FILE_READ | fileFlags);
		if (handle == INVALID_HANDLE)
			return false;

		string jsonData = "";
		while (!FileIsEnding(handle)) {
			jsonData += FileReadString(handle);
		}
		FileClose(handle);

		if (StringLen(jsonData) == 0)
			return true;

		JSON::Array *array = new JSON::Array(jsonData);
		int length = array.getLength();

		for (int i = 0; i < length; i++) {
			if (!array.isObject(i))
				continue;

			string objectJson = array.getObject(i).toString();
			JSON::Object *document = new JSON::Object(objectJson);

			int size = ArraySize(documents);
			ArrayResize(documents, size + 1);
			documents[size] = document;
		}

		delete array;
		return true;
	}

	bool Flush() {
		JSON::Array *array = new JSON::Array();
		int size = ArraySize(documents);

		for (int i = 0; i < size; i++) {
			if (documents[i] == NULL)
				continue;

			string objectJson = documents[i].toString();
			JSON::Object *copy = new JSON::Object(objectJson);
			array.add(copy);
		}

		string jsonData = array.toString();
		delete array;

		ensureDirectoryExists();

		int handle = FileOpen(filePath, FILE_WRITE | fileFlags);
		if (handle == INVALID_HANDLE) {
			Print("[ERROR] SEDbCollection: Cannot write '", name, "' - Error: ", GetLastError());
			return false;
		}

		FileWriteString(handle, jsonData);
		FileClose(handle);
		return true;
	}

	bool InsertOne(JSON::Object *document) {
		if (document == NULL)
			return false;

		string documentJson = document.toString();
		JSON::Object *stored = new JSON::Object(documentJson);

		if (!stored.hasValue("_id"))
			stored.setProperty("_id", generateId());

		int size = ArraySize(documents);
		ArrayResize(documents, size + 1);
		documents[size] = stored;

		if (shouldAutoFlush)
			Flush();

		return true;
	}

	JSON::Object *FindOne(string key, string value) {
		int index = findIndexByKeyValue(key, value);

		if (index == -1)
			return NULL;

		return documents[index];
	}

	int Find(SEDbQuery &query, JSON::Object *&results[]) {
		ArrayResize(results, 0);
		int size = ArraySize(documents);

		for (int i = 0; i < size; i++) {
			if (documents[i] == NULL)
				continue;

			if (query.Matches(documents[i])) {
				int resultSize = ArraySize(results);
				ArrayResize(results, resultSize + 1);
				results[resultSize] = documents[i];
			}
		}

		return ArraySize(results);
	}

	bool UpdateOne(string key, string value, JSON::Object *newData) {
		if (newData == NULL)
			return false;

		int index = findIndexByKeyValue(key, value);
		if (index == -1)
			return false;

		string keys[];
		newData.getKeysToArray(keys);

		for (int i = 0; i < ArraySize(keys); i++) {
			if (newData.isString(keys[i])) {
				documents[index].setProperty(keys[i], newData.getString(keys[i]));
			} else if (newData.isNumber(keys[i])) {
				documents[index].setProperty(keys[i], newData.getNumber(keys[i]));
			} else if (newData.isBoolean(keys[i])) {
				documents[index].setProperty(keys[i], newData.getBoolean(keys[i]));
			} else if (newData.isObject(keys[i])) {
				string objectJson = newData.getObject(keys[i]).toString();
				JSON::Object *objectCopy = new JSON::Object(objectJson);
				documents[index].setProperty(keys[i], objectCopy);
			} else if (newData.isArray(keys[i])) {
				string arrayJson = newData.getArray(keys[i]).toString();
				JSON::Array *arrayCopy = new JSON::Array(arrayJson);
				documents[index].setProperty(keys[i], arrayCopy);
			}
		}

		if (shouldAutoFlush)
			Flush();

		return true;
	}

	bool DeleteOne(string key, string value) {
		int index = findIndexByKeyValue(key, value);
		if (index == -1)
			return false;

		removeAtIndex(index);

		if (shouldAutoFlush)
			Flush();

		return true;
	}

	int Count() {
		return ArraySize(documents);
	}

	bool DeleteFile() {
		int size = ArraySize(documents);

		for (int i = 0; i < size; i++) {
			if (documents[i] != NULL && CheckPointer(documents[i]) == POINTER_DYNAMIC)
				delete documents[i];
		}

		ArrayResize(documents, 0);
		int commonFlag = (fileFlags & FILE_COMMON) != 0 ? FILE_COMMON : 0;

		if (!FileDelete(filePath, commonFlag)) {
			int error = GetLastError();

			if (error != 5002 && error != 5019) {
				Print("[ERROR] SEDbCollection: Cannot delete '", filePath, "' - Error: ", error);
				return false;
			}
		}

		return true;
	}
};

#endif
