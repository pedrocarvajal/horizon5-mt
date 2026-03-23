#ifndef HORIZON_FDB_DATABASE_MANAGER_H
#define HORIZON_FDB_DATABASE_MANAGER_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "../constants/Limits.h"
#include "../entities/Database.h"
#include "../entities/Collection.h"
#include "../entities/Query.h"

#include <string>

class DatabaseManager {
private:
    std::wstring basePath;
    FdbDatabase databases[FDB_MAX_DATABASES];
    int databaseCount;
    CRITICAL_SECTION registryLock;

public:
    DatabaseManager()
        : databaseCount(0)
    {
        InitializeCriticalSection(&registryLock);
    }

    ~DatabaseManager()
    {
        Shutdown();
        DeleteCriticalSection(&registryLock);
    }

    void SetBasePath(const wchar_t* path)
    {
        basePath = path;
    }

    const std::wstring& GetBasePath() const
    {
        return basePath;
    }

    int CreateDatabase(const wchar_t* path)
    {
        EnterCriticalSection(&registryLock);

        for (int i = 0; i < databaseCount; i++) {
            if (databases[i].active && databases[i].path == path) {
                LeaveCriticalSection(&registryLock);
                return i;
            }
        }

        if (databaseCount >= FDB_MAX_DATABASES) {
            LeaveCriticalSection(&registryLock);
            return -1;
        }

        int index = databaseCount;
        databases[index].path = path;
        databases[index].active = true;
        databaseCount++;

        LeaveCriticalSection(&registryLock);
        return index;
    }

    FdbDatabase* GetDatabase(int databaseId)
    {
        if (databaseId < 0 || databaseId >= databaseCount || !databases[databaseId].active) {
            return nullptr;
        }

        return &databases[databaseId];
    }

    void DropDatabase(int databaseId)
    {
        EnterCriticalSection(&registryLock);

        if (databaseId >= 0 && databaseId < databaseCount && databases[databaseId].active) {
            databases[databaseId].collectionIds.clear();
            databases[databaseId].active = false;
        }

        LeaveCriticalSection(&registryLock);
    }

    void Shutdown()
    {
        EnterCriticalSection(&registryLock);

        for (int i = 0; i < databaseCount; i++) {
            databases[i].collectionIds.clear();
            databases[i].active = false;
        }

        databaseCount = 0;
        LeaveCriticalSection(&registryLock);
    }
};

#endif
