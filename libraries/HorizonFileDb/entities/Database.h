#ifndef HORIZON_FDB_DATABASE_H
#define HORIZON_FDB_DATABASE_H

#include <string>
#include <vector>

struct FdbDatabase {
    std::wstring path;
    std::vector<int> collectionIds;
    bool active;

    FdbDatabase()
        : active(false)
    {
    }
};

#endif
