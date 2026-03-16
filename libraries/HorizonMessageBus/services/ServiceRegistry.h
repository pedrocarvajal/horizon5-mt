#ifndef HORIZON_MB_SERVICE_REGISTRY_H
#define HORIZON_MB_SERVICE_REGISTRY_H

#include "../constants/Limits.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <string>

struct ServiceEntry {
    std::wstring name;
    long long registeredAt;
    bool active;
};

class ServiceRegistry {
private:
    ServiceEntry services[MB_MAX_SERVICES];
    int serviceCount;
    CRITICAL_SECTION lock;

public:
    ServiceRegistry()
        : serviceCount(0)
    {
        InitializeCriticalSection(&lock);
    }

    ~ServiceRegistry()
    {
        DeleteCriticalSection(&lock);
    }

    void Register(const wchar_t* serviceName)
    {
        EnterCriticalSection(&lock);

        int index = findService(serviceName);

        if (index >= 0) {
            services[index].registeredAt = static_cast<long long>(GetTickCount64());
            services[index].active = true;
            LeaveCriticalSection(&lock);
            return;
        }

        if (serviceCount >= MB_MAX_SERVICES) {
            LeaveCriticalSection(&lock);
            return;
        }

        services[serviceCount].name = serviceName;
        services[serviceCount].registeredAt = static_cast<long long>(GetTickCount64());
        services[serviceCount].active = true;
        serviceCount++;

        LeaveCriticalSection(&lock);
    }

    void Unregister(const wchar_t* serviceName)
    {
        EnterCriticalSection(&lock);

        int index = findService(serviceName);

        if (index >= 0) {
            services[index].active = false;
        }

        LeaveCriticalSection(&lock);
    }

    bool IsRunning(const wchar_t* serviceName)
    {
        EnterCriticalSection(&lock);

        int index = findService(serviceName);
        bool running = (index >= 0 && services[index].active);

        LeaveCriticalSection(&lock);
        return running;
    }

    void Shutdown()
    {
        EnterCriticalSection(&lock);

        for (int i = 0; i < serviceCount; i++) {
            services[i].active = false;
        }

        serviceCount = 0;
        LeaveCriticalSection(&lock);
    }

private:
    int findService(const wchar_t* serviceName) const
    {
        std::wstring name(serviceName);

        for (int i = 0; i < serviceCount; i++) {
            if (services[i].name == name) {
                return i;
            }
        }

        return -1;
    }
};

#endif
