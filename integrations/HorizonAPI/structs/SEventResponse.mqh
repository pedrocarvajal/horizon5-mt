#ifndef __S_EVENT_RESPONSE_MQH__
#define __S_EVENT_RESPONSE_MQH__

struct SEventResponse {
	bool success;
	string message;

	SEventResponse() {
		success = false;
		message = "";
	}

	void Success() {
		success = true;
		message = "";
	}

	void Error(string errorMessage) {
		success = false;
		message = errorMessage;
	}

	void ApplyTo(JSON::Object &target) {
		target.setProperty("status", success ? "success" : "error");

		if (message != "") {
			target.setProperty("message", message);
		}
	}
};

#endif
