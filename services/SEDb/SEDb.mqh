#ifndef __SE_DB_MQH__
#define __SE_DB_MQH__

#include "SEFileDbDLL.mqh"
#include "SEDbCollection.mqh"
#include "../../entities/EAccount.mqh"

class SEDb {
private:
	int databaseHandle;
	string basePath;
	bool useCommonFiles;
	bool isInitialized;
	static bool dllInitialized;
	SEDbCollection *collections[];

public:
	SEDb() {
		databaseHandle = -1;
		basePath = "";
		useCommonFiles = false;
		isInitialized = false;
	}

	void Initialize(string databasePath, bool commonFiles = false) {
		if (!dllInitialized) {
			string commonDataPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files";
			FdbInit(commonDataPath);
			dllInitialized = true;
		}

		EAccount localAccount;
		long accountNumber = localAccount.GetNumber();
		basePath = StringFormat("%lld/%s", accountNumber, databasePath);
		useCommonFiles = commonFiles;
		databaseHandle = FdbDatabaseCreate(basePath);
		isInitialized = true;
	}

	~SEDb() {
		int size = ArraySize(collections);

		for (int i = 0; i < size; i++) {
			if (collections[i] != NULL && CheckPointer(collections[i]) == POINTER_DYNAMIC) {
				delete collections[i];
			}
		}

		ArrayResize(collections, 0);
	}

	SEDbCollection *Collection(string collectionName) {
		if (!isInitialized) {
			Print("[ERROR] SEDb: Database not initialized");
			return NULL;
		}

		int index = FindCollectionIndex(collectionName);

		if (index != -1) {
			return collections[index];
		}

		int collectionHandle = FdbCollectionGet(databaseHandle, collectionName);

		if (collectionHandle == -1) {
			Print("[ERROR] SEDb: Cannot create collection '", collectionName, "'");
			return NULL;
		}

		FdbCollectionLoad(collectionHandle);

		SEDbCollection *collection = new SEDbCollection();
		collection.Initialize(collectionName, collectionHandle, basePath, useCommonFiles);

		int size = ArraySize(collections);
		ArrayResize(collections, size + 1);
		collections[size] = collection;

		return collection;
	}

	bool Drop(string collectionName) {
		if (!isInitialized) {
			Print("[ERROR] SEDb: Database not initialized");
			return false;
		}

		int index = FindCollectionIndex(collectionName);
		if (index == -1) {
			return false;
		}

		collections[index].DeleteFile();

		if (CheckPointer(collections[index]) == POINTER_DYNAMIC) {
			delete collections[index];
		}

		int size = ArraySize(collections);
		for (int i = index; i < size - 1; i++) {
			collections[i] = collections[i + 1];
		}
		ArrayResize(collections, size - 1);

		return true;
	}

	int GetCollectionCount() {
		return ArraySize(collections);
	}

private:
	int FindCollectionIndex(string collectionName) {
		int size = ArraySize(collections);

		for (int i = 0; i < size; i++) {
			if (collections[i] != NULL && collections[i].GetName() == collectionName) {
				return i;
			}
		}

		return -1;
	}
};

bool SEDb::dllInitialized = false;

#endif
