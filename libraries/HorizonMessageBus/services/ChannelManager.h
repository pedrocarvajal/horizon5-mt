#ifndef HORIZON_MB_CHANNEL_MANAGER_H
#define HORIZON_MB_CHANNEL_MANAGER_H

#include "../constants/Limits.h"
#include "../entities/Message.h"
#include "../helpers/RingBuffer.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <string>

struct Channel {
    std::wstring name;
    RingBuffer ringBuffer;
    CRITICAL_SECTION lock;
    HANDLE newMessageEvent;
    bool active;
};

class ChannelManager {
private:
    Channel channels[MB_MAX_CHANNELS];
    int channelCount;
    CRITICAL_SECTION registryLock;

public:
    ChannelManager()
        : channelCount(0)
    {
        InitializeCriticalSection(&registryLock);
    }

    ~ChannelManager()
    {
        Shutdown();
        DeleteCriticalSection(&registryLock);
    }

    void Shutdown()
    {
        EnterCriticalSection(&registryLock);

        for (int i = 0; i < channelCount; i++) {
            if (channels[i].active) {
                DeleteCriticalSection(&channels[i].lock);
                CloseHandle(channels[i].newMessageEvent);
                channels[i].active = false;
            }
        }

        channelCount = 0;
        LeaveCriticalSection(&registryLock);
    }

    int CreateChannel(const wchar_t* channelName, int capacity)
    {
        EnterCriticalSection(&registryLock);

        int existingIndex = FindChannel(channelName);

        if (existingIndex >= 0) {
            LeaveCriticalSection(&registryLock);
            return existingIndex;
        }

        if (channelCount >= MB_MAX_CHANNELS) {
            LeaveCriticalSection(&registryLock);
            return -1;
        }

        int index = channelCount;
        channels[index].name = channelName;
        channels[index].ringBuffer.Initialize(capacity);
        InitializeCriticalSection(&channels[index].lock);
        channels[index].newMessageEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
        channels[index].active = true;
        channelCount++;

        LeaveCriticalSection(&registryLock);
        return index;
    }

    int FindChannel(const wchar_t* channelName) const
    {
        for (int i = 0; i < channelCount; i++) {
            if (channels[i].active && channels[i].name == channelName) {
                return i;
            }
        }

        return -1;
    }

    int GetOrCreateChannel(const wchar_t* channelName)
    {
        int index = FindChannel(channelName);

        if (index >= 0) {
            return index;
        }

        return CreateChannel(channelName, MB_DEFAULT_CHANNEL_CAPACITY);
    }

    long long Publish(int channelIndex, const wchar_t* messageType, const wchar_t* payload)
    {
        if (channelIndex < 0 || channelIndex >= channelCount || !channels[channelIndex].active) {
            return -1;
        }

        Channel& channel = channels[channelIndex];

        EnterCriticalSection(&channel.lock);

        long long timestamp = static_cast<long long>(GetTickCount64());
        long long sequence = channel.ringBuffer.Push(
            std::wstring(messageType),
            std::wstring(payload),
            timestamp);

        SetEvent(channel.newMessageEvent);

        LeaveCriticalSection(&channel.lock);

        return sequence;
    }

    int Poll(int channelIndex, long long afterSequence, Message* results, int maxResults)
    {
        if (channelIndex < 0 || channelIndex >= channelCount || !channels[channelIndex].active) {
            return 0;
        }

        Channel& channel = channels[channelIndex];

        EnterCriticalSection(&channel.lock);
        int count = channel.ringBuffer.Read(afterSequence, results, maxResults);
        LeaveCriticalSection(&channel.lock);

        return count;
    }

    int Ack(int channelIndex, long long upToSequence)
    {
        if (channelIndex < 0 || channelIndex >= channelCount || !channels[channelIndex].active) {
            return 0;
        }

        Channel& channel = channels[channelIndex];

        EnterCriticalSection(&channel.lock);
        channel.ringBuffer.AdvanceTail(upToSequence);

        if (channel.ringBuffer.IsEmpty()) {
            ResetEvent(channel.newMessageEvent);
        }

        LeaveCriticalSection(&channel.lock);

        return 1;
    }

    int WaitForMessage(int channelIndex, int timeoutMs)
    {
        if (channelIndex < 0 || channelIndex >= channelCount || !channels[channelIndex].active) {
            return 0;
        }

        DWORD result = WaitForSingleObject(channels[channelIndex].newMessageEvent, timeoutMs);
        return (result == WAIT_OBJECT_0) ? 1 : 0;
    }

    int GetPendingCount(int channelIndex) const
    {
        if (channelIndex < 0 || channelIndex >= channelCount || !channels[channelIndex].active) {
            return 0;
        }

        return channels[channelIndex].ringBuffer.GetPendingCount();
    }
};

#endif
