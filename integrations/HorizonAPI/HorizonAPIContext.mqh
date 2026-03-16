#ifndef __HORIZON_API_CONTEXT_MQH__
#define __HORIZON_API_CONTEXT_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../services/SEMessageBus/SEMessageBus.mqh"
#include "../../services/SEMessageBus/SEMessageBusChannels.mqh"

class HorizonAPIContext {
private:
	SERequest * request;
	long accountId;
	bool isEnabled;

public:
	HorizonAPIContext() {
		request = NULL;
		accountId = 0;
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

	long GetAccountId() {
		return accountId;
	}

	void SetAccountId(long id) {
		accountId = id;
	}

	void Post(string path, JSON::Object &body) {
		if (SEMessageBus::IsActive()) {
			JSON::Object payload;
			payload.setProperty("path", path);

			string bodyJson = body.toString();
			JSON::Object *bodyCopy = new JSON::Object(bodyJson);
			payload.setProperty("body", bodyCopy);

			SEMessageBus::Send(MB_CHANNEL_CONNECTOR, "http_post", payload);
			return;
		}

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
