#ifndef __SE_DB_MQH__
#define __SE_DB_MQH__

#include "../SELogger/SELogger.mqh"
#include "SEDbCollection.mqh"

class SEDb {
private:
	SELogger logger;
	string basePath;
	bool useCommonFiles;
	bool initialized;
	SEDbCollection *collections[];

public:
	SEDb() {
		basePath = "";
		useCommonFiles = false;
		initialized = false;
		logger.SetPrefix("SEDb");
	}

	void Initialize(string databasePath, bool commonFiles = false) {
		long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
		basePath = StringFormat("%lld/%s", accountNumber, databasePath);
		useCommonFiles = commonFiles;
		initialized = true;
		logger.SetPrefix(StringFormat("SEDb[%s]", basePath));
	}

	~SEDb() {
		int size = ArraySize(collections);

		for (int i = 0; i < size; i++) {
			if (collections[i] != NULL && CheckPointer(collections[i]) == POINTER_DYNAMIC)
				delete collections[i];
		}

		ArrayResize(collections, 0);
	}

	SEDbCollection *Collection(string collectionName) {
		if (!initialized) {
			logger.error("Database not initialized");
			return NULL;
		}

		int index = FindCollectionIndex(collectionName);

		if (index != -1)
			return collections[index];

		SEDbCollection *collection = new SEDbCollection();
		collection.Initialize(collectionName, basePath, useCommonFiles);
		collection.Load();

		int size = ArraySize(collections);
		ArrayResize(collections, size + 1);
		collections[size] = collection;

		logger.info(StringFormat("Collection '%s' ready (%d documents)", collectionName, collection.Count()));
		return collection;
	}

	bool Drop(string collectionName) {
		if (!initialized) {
			logger.error("Database not initialized");
			return false;
		}

		int index = FindCollectionIndex(collectionName);
		if (index == -1) {
			logger.warning(StringFormat("Collection '%s' not found", collectionName));
			return false;
		}

		collections[index].DeleteFile();

		if (CheckPointer(collections[index]) == POINTER_DYNAMIC)
			delete collections[index];

		int size = ArraySize(collections);
		for (int i = index; i < size - 1; i++) {
			collections[i] = collections[i + 1];
		}
		ArrayResize(collections, size - 1);

		logger.info(StringFormat("Collection '%s' dropped", collectionName));
		return true;
	}

	int GetCollectionCount() {
		return ArraySize(collections);
	}

private:
	int FindCollectionIndex(string collectionName) {
		int size = ArraySize(collections);

		for (int i = 0; i < size; i++) {
			if (collections[i] != NULL && collections[i].GetName() == collectionName)
				return i;
		}

		return -1;
	}
};

#endif
