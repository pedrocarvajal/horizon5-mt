#ifndef HORIZON_MESSAGE_BUS_H
#define HORIZON_MESSAGE_BUS_H

#ifdef HORIZON_MB_EXPORTS
#define MB_API __declspec(dllexport)
#else
#define MB_API __declspec(dllimport)
#endif

extern "C" {

MB_API int __stdcall MbInit();
MB_API void __stdcall MbShutdown();

MB_API int __stdcall MbChannelCreate(const wchar_t* channelName, int capacity);
MB_API int __stdcall MbChannelFind(const wchar_t* channelName);
MB_API int __stdcall MbChannelGetOrCreate(const wchar_t* channelName);

MB_API long long __stdcall MbPublish(int channelId, const wchar_t* messageType, const wchar_t* payload);

MB_API int __stdcall MbPoll(int channelId, long long afterSequence, int maxMessages);
MB_API long long __stdcall MbResultGetSequence(int index);
MB_API void __stdcall MbResultGetType(int index, wchar_t* buffer, int bufferSize);
MB_API void __stdcall MbResultGetPayload(int index, wchar_t* buffer, int bufferSize);
MB_API long long __stdcall MbResultGetTimestamp(int index);

MB_API int __stdcall MbAck(int channelId, long long upToSequence);
MB_API int __stdcall MbGetPendingCount(int channelId);
MB_API int __stdcall MbWaitForMessage(int channelId, int timeoutMs);

MB_API void __stdcall MbServiceRegister(const wchar_t* serviceName);
MB_API void __stdcall MbServiceUnregister(const wchar_t* serviceName);
MB_API int __stdcall MbServiceIsRunning(const wchar_t* serviceName);

}

#endif
