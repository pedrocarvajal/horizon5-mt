#ifndef __S_MESSAGE_MQH__
#define __S_MESSAGE_MQH__

struct SMessage {
	long sequence;
	string messageType;
	long timestamp;
	string payloadJson;

	SMessage() {
		sequence = -1;
		messageType = "";
		timestamp = 0;
		payloadJson = "";
	}
};

#endif
