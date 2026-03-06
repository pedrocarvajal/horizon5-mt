#ifndef __HORIZON_API_CONTEXT_MQH__
#define __HORIZON_API_CONTEXT_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"

class HorizonAPIContext {
private:
	long accountId;
	bool isEnabled;

public:
	SERequest * request;

	HorizonAPIContext() {
		request = NULL;
		accountId = 0;
		isEnabled = false;
	}

	bool IsEnabled() {
		return isEnabled;
	}

	void Enable() {
		isEnabled = true;
	}

	void Disable() {
		isEnabled = false;
	}

	long GetAccountId() {
		return accountId;
	}

	void SetAccountId(long id) {
		accountId = id;
	}

	void Post(string path, JSON::Object &body) {
		request.Post(path, body);
	}

	SRequestResponse PostWithResponse(string path, JSON::Object &body, int timeout = 0) {
		return request.Post(path, body, timeout);
	}

	SRequestResponse Get(string path) {
		return request.Get(path);
	}

	SRequestResponse Patch(string path, JSON::Object &body) {
		return request.Patch(path, body);
	}

	SRequestResponse PostMultipart(string path, string fieldName, string fileName, char &fileData[], string contentType = "text/csv") {
		return request.PostMultipart(path, fieldName, fileName, fileData, contentType);
	}
};

#endif
