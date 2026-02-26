#ifndef __S_REQUEST_RESPONSE_MQH__
#define __S_REQUEST_RESPONSE_MQH__

struct SRequestResponse {
	string body;
	int status;
	ulong delay;

	SRequestResponse() {
		body = "";
		status = 0;
		delay = 0;
	}
};

#endif
