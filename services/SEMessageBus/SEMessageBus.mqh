#ifndef __SE_MESSAGE_BUS_MQH__
#define __SE_MESSAGE_BUS_MQH__

#include "../../libraries/Json/index.mqh"

#include "structs/SMessage.mqh"

#include "SEMessageBusDLL.mqh"

#include "../SELogger/SELogger.mqh"

#include "../../constants/COMessageBus.mqh"

class SEMessageBus {
private:
	static bool active;
	static SELogger logger;

public:
	static bool Initialize() {
		logger.SetPrefix("SEMessageBus");
		int result = MbInit();

		if (result != 1) {
			logger.Error(
				LOG_CODE_FRAMEWORK_INIT_FAILED,
				"message bus init failed | reason='dll initialization failed'"
			);
			return false;
		}

		return true;
	}

	static void Shutdown() {
		active = false;
	}

	static void Activate() {
		logger.SetPrefix("SEMessageBus");
		active = true;
	}

	static bool IsActive() {
		return active;
	}

	static bool Send(string channel, string messageType, JSON::Object &payload) {
		int channelId = MbChannelGetOrCreate(channel);

		if (channelId < 0) {
			logger.Error(
				LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
				StringFormat(
					"message bus channel failed | channel=%s reason='get or create failed'",
					channel
			));
			return false;
		}

		string payloadStr = payload.toString();
		long sequence = MbPublish(channelId, messageType, payloadStr);

		if (sequence < 0) {
			logger.Error(
				LOG_CODE_FRAMEWORK_INTERNAL_ERROR,
				StringFormat(
					"message bus publish failed | channel=%s",
					channel
			));
			return false;
		}

		return true;
	}

	static int Poll(string channel, SMessage &messages[]) {
		ArrayResize(messages, 0);

		int channelId = MbChannelGetOrCreate(channel);

		if (channelId < 0) {
			return 0;
		}

		int count = MbPoll(channelId, -1, MB_PAYLOAD_BUFFER_SIZE);

		if (count == 0) {
			return 0;
		}

		ArrayResize(messages, count);

		for (int i = 0; i < count; i++) {
			messages[i].sequence = MbResultGetSequence(i);
			messages[i].timestamp = MbResultGetTimestamp(i);

			string typeBuffer = "";
			StringInit(typeBuffer, MB_TYPE_BUFFER_SIZE, 0);
			MbResultGetType(i, typeBuffer, MB_TYPE_BUFFER_SIZE);
			messages[i].messageType = typeBuffer;

			string payloadBuffer = "";
			StringInit(payloadBuffer, MB_PAYLOAD_BUFFER_SIZE, 0);
			MbResultGetPayload(i, payloadBuffer, MB_PAYLOAD_BUFFER_SIZE);
			messages[i].payloadJson = payloadBuffer;
		}

		return count;
	}

	static bool Ack(string channel, long sequence) {
		int channelId = MbChannelFind(channel);

		if (channelId < 0) {
			return false;
		}

		return MbAck(channelId, sequence) == 1;
	}

	static void RegisterService(string serviceName) {
		MbServiceRegister(serviceName);
	}

	static void UnregisterService(string serviceName) {
		MbServiceUnregister(serviceName);
	}

	static bool IsServiceRunning(string serviceName) {
		return MbServiceIsRunning(serviceName) == 1;
	}

	static bool AreServicesReady(string &serviceNames[], int count) {
		for (int i = 0; i < count; i++) {
			if (!IsServiceRunning(serviceNames[i])) {
				return false;
			}
		}

		return true;
	}

	static bool HasChanges(string channel, double &cachedCounter) {
		int channelId = MbChannelFind(channel);

		if (channelId < 0) {
			return false;
		}

		double pendingCount = (double)MbGetPendingCount(channelId);

		if (pendingCount != cachedCounter) {
			cachedCounter = pendingCount;
			return true;
		}

		return false;
	}

	static int GetPendingCount(string channel) {
		int channelId = MbChannelFind(channel);

		if (channelId < 0) {
			return 0;
		}

		return MbGetPendingCount(channelId);
	}

	static int WaitForMessage(string channel, int timeoutMs) {
		int channelId = MbChannelFind(channel);

		if (channelId < 0) {
			return 0;
		}

		return MbWaitForMessage(channelId, timeoutMs);
	}
};

bool SEMessageBus::active = false;
SELogger SEMessageBus::logger;

#endif
