#ifndef __SE_MESSAGE_BUS_DLL_MQH__
#define __SE_MESSAGE_BUS_DLL_MQH__

#import "HorizonMessageBus.dll"

int MbInit();
void MbShutdown();

int MbChannelCreate(const string channelName, int capacity);
int MbChannelFind(const string channelName);
int MbChannelGetOrCreate(const string channelName);

long MbPublish(int channelId, const string messageType, const string payload);

int MbPoll(int channelId, long afterSequence, int maxMessages);
long MbResultGetSequence(int index);
void MbResultGetType(int index, string &buffer, int bufferSize);
void MbResultGetPayload(int index, string &buffer, int bufferSize);
long MbResultGetTimestamp(int index);

int MbAck(int channelId, long upToSequence);
int MbGetPendingCount(int channelId);
int MbWaitForMessage(int channelId, int timeoutMs);

void MbServiceRegister(const string serviceName);
void MbServiceUnregister(const string serviceName);
int MbServiceIsRunning(const string serviceName);

#import

#endif
