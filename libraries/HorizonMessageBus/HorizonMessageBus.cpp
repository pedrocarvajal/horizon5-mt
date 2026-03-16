#define HORIZON_MB_EXPORTS

#include "HorizonMessageBus.h"
#include "constants/Limits.h"
#include "entities/Message.h"
#include "services/ChannelManager.h"
#include "services/ServiceRegistry.h"

#include <algorithm>

static ChannelManager* channelManager = nullptr;
static ServiceRegistry* serviceRegistry = nullptr;
static bool initialized = false;

thread_local Message pollResults[MB_MAX_POLL_RESULTS];
thread_local int pollResultCount = 0;

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved)
{
    switch (reason) {
    case DLL_PROCESS_ATTACH:
        DisableThreadLibraryCalls(hModule);
        break;
    case DLL_PROCESS_DETACH:
        if (initialized) {
            delete channelManager;
            delete serviceRegistry;
            channelManager = nullptr;
            serviceRegistry = nullptr;
            initialized = false;
        }
        break;
    }

    return TRUE;
}

extern "C" {

MB_API int __stdcall MbInit()
{
    if (initialized) {
        return 1;
    }

    channelManager = new ChannelManager();
    serviceRegistry = new ServiceRegistry();
    initialized = true;

    return 1;
}

MB_API void __stdcall MbShutdown()
{
    if (!initialized) {
        return;
    }

    channelManager->Shutdown();
    serviceRegistry->Shutdown();

    delete channelManager;
    delete serviceRegistry;

    channelManager = nullptr;
    serviceRegistry = nullptr;
    initialized = false;
}

MB_API int __stdcall MbChannelCreate(const wchar_t* channelName, int capacity)
{
    if (!initialized || channelName == nullptr) {
        return -1;
    }

    return channelManager->CreateChannel(channelName, capacity);
}

MB_API int __stdcall MbChannelFind(const wchar_t* channelName)
{
    if (!initialized || channelName == nullptr) {
        return -1;
    }

    return channelManager->FindChannel(channelName);
}

MB_API int __stdcall MbChannelGetOrCreate(const wchar_t* channelName)
{
    if (!initialized || channelName == nullptr) {
        return -1;
    }

    return channelManager->GetOrCreateChannel(channelName);
}

MB_API long long __stdcall MbPublish(int channelId, const wchar_t* messageType, const wchar_t* payload)
{
    if (!initialized) {
        return -1;
    }

    return channelManager->Publish(channelId, messageType, payload);
}

MB_API int __stdcall MbPoll(int channelId, long long afterSequence, int maxMessages)
{
    if (!initialized) {
        return 0;
    }

    int limit = (std::min)(maxMessages, MB_MAX_POLL_RESULTS);
    pollResultCount = channelManager->Poll(channelId, afterSequence, pollResults, limit);

    return pollResultCount;
}

MB_API long long __stdcall MbResultGetSequence(int index)
{
    if (index < 0 || index >= pollResultCount) {
        return -1;
    }

    return pollResults[index].sequence;
}

MB_API void __stdcall MbResultGetType(int index, wchar_t* buffer, int bufferSize)
{
    if (index < 0 || index >= pollResultCount || buffer == nullptr || bufferSize <= 0) {
        return;
    }

    const std::wstring& type = pollResults[index].type;
    int copyLength = (std::min)(static_cast<int>(type.size()), bufferSize - 1);
    wcsncpy_s(buffer, bufferSize, type.c_str(), copyLength);
}

MB_API void __stdcall MbResultGetPayload(int index, wchar_t* buffer, int bufferSize)
{
    if (index < 0 || index >= pollResultCount || buffer == nullptr || bufferSize <= 0) {
        return;
    }

    const std::wstring& payload = pollResults[index].payload;
    int copyLength = (std::min)(static_cast<int>(payload.size()), bufferSize - 1);
    wcsncpy_s(buffer, bufferSize, payload.c_str(), copyLength);
}

MB_API long long __stdcall MbResultGetTimestamp(int index)
{
    if (index < 0 || index >= pollResultCount) {
        return 0;
    }

    return pollResults[index].timestamp;
}

MB_API int __stdcall MbAck(int channelId, long long upToSequence)
{
    if (!initialized) {
        return 0;
    }

    return channelManager->Ack(channelId, upToSequence);
}

MB_API int __stdcall MbGetPendingCount(int channelId)
{
    if (!initialized) {
        return 0;
    }

    return channelManager->GetPendingCount(channelId);
}

MB_API int __stdcall MbWaitForMessage(int channelId, int timeoutMs)
{
    if (!initialized) {
        return 0;
    }

    return channelManager->WaitForMessage(channelId, timeoutMs);
}

MB_API void __stdcall MbServiceRegister(const wchar_t* serviceName)
{
    if (!initialized || serviceName == nullptr) {
        return;
    }

    serviceRegistry->Register(serviceName);
}

MB_API void __stdcall MbServiceUnregister(const wchar_t* serviceName)
{
    if (!initialized || serviceName == nullptr) {
        return;
    }

    serviceRegistry->Unregister(serviceName);
}

MB_API int __stdcall MbServiceIsRunning(const wchar_t* serviceName)
{
    if (!initialized || serviceName == nullptr) {
        return 0;
    }

    return serviceRegistry->IsRunning(serviceName) ? 1 : 0;
}

}
