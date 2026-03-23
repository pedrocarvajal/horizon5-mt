#ifndef HORIZON_FDB_UUID_GENERATOR_H
#define HORIZON_FDB_UUID_GENERATOR_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>

#include <string>
#include <cstdio>

#pragma comment(lib, "bcrypt.lib")

class UuidGenerator {
public:
    static std::string Generate()
    {
        unsigned char bytes[16];

        NTSTATUS status = BCryptGenRandom(NULL, bytes, sizeof(bytes), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
        if (status != 0) {
            return FallbackGenerate();
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x40;
        bytes[8] = (bytes[8] & 0x3F) | 0x80;

        char uuid[37];
        snprintf(uuid, sizeof(uuid),
            "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);

        return std::string(uuid);
    }

private:
    static std::string FallbackGenerate()
    {
        unsigned char bytes[16];
        LARGE_INTEGER counter;
        QueryPerformanceCounter(&counter);

        DWORD tick = GetTickCount();
        DWORD pid = GetCurrentProcessId();
        DWORD tid = GetCurrentThreadId();

        unsigned long long seed = static_cast<unsigned long long>(counter.QuadPart) ^
                                  (static_cast<unsigned long long>(tick) << 32) ^
                                  (static_cast<unsigned long long>(pid) << 16) ^
                                  static_cast<unsigned long long>(tid);

        for (int i = 0; i < 16; i++) {
            seed = seed * 6364136223846793005ULL + 1442695040888963407ULL;
            bytes[i] = static_cast<unsigned char>(seed >> 33);
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x40;
        bytes[8] = (bytes[8] & 0x3F) | 0x80;

        char uuid[37];
        snprintf(uuid, sizeof(uuid),
            "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);

        return std::string(uuid);
    }
};

#endif
