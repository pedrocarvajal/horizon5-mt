#ifndef __HORIZON_MONITOR_CONTEXT_MQH__
#define __HORIZON_MONITOR_CONTEXT_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../services/SEMessageBus/SEMessageBus.mqh"

#include "../../constants/COMessageBus.mqh"

class HorizonMonitorContext {
private:
	SERequest * request;
	long accountNumber;
	string brokerServer;
	string accountUuid;
	bool isEnabled;

public:
	HorizonMonitorContext() {
		request = NULL;
		accountNumber = 0;
		brokerServer = "";
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

	long GetAccountNumber() {
		return accountNumber;
	}

	void SetAccountNumber(long number) {
		accountNumber = number;
	}

	string GetBrokerServer() {
		return brokerServer;
	}

	void SetBrokerServer(string server) {
		brokerServer = server;
	}

	string GetAccountUuid() {
		return accountUuid;
	}

	void SetAccountUuid(string uuid) {
		accountUuid = uuid;
	}

	SRequestResponse Post(string path, JSON::Object &body, bool async = true) {
		if (async && SEMessageBus::IsActive()) {
			JSON::Object payload;
			payload.setProperty("path", path);

			string bodyJson = body.toString();
			JSON::Object *bodyCopy = new JSON::Object(bodyJson);
			payload.setProperty("body", bodyCopy);

			SEMessageBus::Send(MB_CHANNEL_CONNECTOR, "http_post", payload);

			SRequestResponse emptyResponse;
			return emptyResponse;
		}

		return request.Post(path, body);
	}
};

#endif
