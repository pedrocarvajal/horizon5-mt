#ifndef __HORIZON_GATEWAY_CONTEXT_MQH__
#define __HORIZON_GATEWAY_CONTEXT_MQH__

#include "../../services/SERequest/SERequest.mqh"

class HorizonGatewayContext {
private:
	SERequest * request;
	string accountUuid;
	bool isEnabled;

public:
	HorizonGatewayContext() {
		request = NULL;
		accountUuid = "";
		isEnabled = false;
	}

	SERequest *GetRequest() {
		return request;
	}

	void SetRequest(SERequest *req) {
		request = req;
	}

	bool HasRequest() {
		return request != NULL;
	}

	void DeleteRequest() {
		if (request != NULL && CheckPointer(request) == POINTER_DYNAMIC) {
			delete request;
			request = NULL;
		}
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

	string GetAccountUuid() {
		return accountUuid;
	}

	void SetAccountUuid(string uuid) {
		accountUuid = uuid;
	}

	SRequestResponse Post(string path, JSON::Object &body, int timeout = 0) {
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
