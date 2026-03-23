#ifndef HORIZON_FDB_DATABASE_MANAGER_H
#define HORIZON_FDB_DATABASE_MANAGER_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "../entities/Database.h"

#include <string>
#include <vector>

class DatabaseManager {
private:
    std::wstring basePath;
    std::vector<FdbDatabase> databases;
    CRITICAL_SECTION registryLock;

public:
    DatabaseManager()
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

        int count = static_cast<int>(databases.size());

        for (int i = 0; i < count; i++) {
            if (databases[i].active && databases[i].path == path) {
                LeaveCriticalSection(&registryLock);
                return i;
            }
        }

        FdbDatabase db;
        db.path = path;
        db.active = true;

        int index = count;
        databases.push_back(std::move(db));

        LeaveCriticalSection(&registryLock);
        return index;
    }

    FdbDatabase* GetDatabase(int databaseId)
    {
        if (databaseId < 0 || databaseId >= static_cast<int>(databases.size()) || !databases[databaseId].active) {
            return nullptr;
        }

        return &databases[databaseId];
    }

    void DropDatabase(int databaseId)
    {
        EnterCriticalSection(&registryLock);

        if (databaseId >= 0 && databaseId < static_cast<int>(databases.size()) && databases[databaseId].active) {
            databases[databaseId].collectionIds.clear();
            databases[databaseId].active = false;
        }

        LeaveCriticalSection(&registryLock);
    }

    void Shutdown()
    {
        EnterCriticalSection(&registryLock);

        for (auto& db : databases) {
            db.collectionIds.clear();
            db.active = false;
        }

        databases.clear();
        LeaveCriticalSection(&registryLock);
    }
};

#endif
