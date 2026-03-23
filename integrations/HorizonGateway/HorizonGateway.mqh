#ifndef __HORIZON_GATEWAY_MQH__
#define __HORIZON_GATEWAY_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../services/SEMessageBus/SEMessageBus.mqh"
#include "../../services/SEMessageBus/SEMessageBusChannels.mqh"

#include "../../entities/EAccount.mqh"
#include "../../helpers/HGetAccountUuid.mqh"
#include "../../helpers/HGetAssetUuid.mqh"
#include "../../helpers/HGetStrategyUuid.mqh"

#include "HorizonGatewayContext.mqh"
#include "structs/SGatewayEvent.mqh"
#include "structs/SGatewayAssetMapping.mqh"
#include "structs/SGatewayStrategyMapping.mqh"
#include "resources/EventResource.mqh"

#define SAFE_DELETE(ptr) do { if (ptr != NULL && CheckPointer(ptr) == POINTER_DYNAMIC) { delete ptr; } ptr = NULL; } while (0)

class HorizonGateway {
private:
	HorizonGatewayContext context;
	SELogger logger;
	EAccount account;

	EventResource *events;

	SGatewayAssetMapping registeredAssets[];
	SGatewayStrategyMapping registeredStrategies[];

	void registerAsset(string symbolName, string uuid) {
		for (int i = 0; i < ArraySize(registeredAssets); i++) {
			if (registeredAssets[i].GetSymbol() == symbolName) {
				registeredAssets[i].SetUuid(uuid);
				return;
			}
		}

		int size = ArraySize(registeredAssets);
		ArrayResize(registeredAssets, size + 1);
		registeredAssets[size].SetSymbol(symbolName);
		registeredAssets[size].SetUuid(uuid);
	}

	void registerStrategy(ulong magicNumber, string uuid) {
		for (int i = 0; i < ArraySize(registeredStrategies); i++) {
			if (registeredStrategies[i].GetMagicNumber() == magicNumber) {
				registeredStrategies[i].SetUuid(uuid);
				return;
			}
		}

		int size = ArraySize(registeredStrategies);
		ArrayResize(registeredStrategies, size + 1);
		registeredStrategies[size].SetMagicNumber(magicNumber);
		registeredStrategies[size].SetUuid(uuid);
	}

	string parseUuidFromResponse(SRequestResponse &response) {
		if (response.status != 200 && response.status != 201) {
			return "";
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			return "";
		}

		JSON::Object *dataObject = root.getObject("data");
		return dataObject.getString("id");
	}

	void trimKeyArray(string &keyArray[]) {
		for (int i = 0; i < ArraySize(keyArray); i++) {
			StringTrimLeft(keyArray[i]);
			StringTrimRight(keyArray[i]);
		}
	}

	bool matchesKey(const string eventKey, string &keyArray[]) {
		for (int k = 0; k < ArraySize(keyArray); k++) {
			if (keyArray[k] == eventKey) {
				return true;
			}
		}

		return false;
	}

	bool matchesFilters(JSON::Object *payload, const string symbolFilter, int strategyFilter) {
		if (strategyFilter > 0) {
			int eventStrategy = (int)payload.getNumber("strategy_id");
			if (eventStrategy != 0 && eventStrategy != strategyFilter) {
				return false;
			}
		}

		if (symbolFilter != "") {
			string eventSymbol = payload.getString("symbol");
			if (eventSymbol != "" && eventSymbol != symbolFilter) {
				return false;
			}
		}

		return true;
	}

	int consumeEventsFromBus(const string keys, const string symbolFilter, SGatewayEvent &eventList[], int limit, int strategyFilter) {
		SMessage messages[];
		int count = SEMessageBus::Poll(MB_CHANNEL_EVENTS_IN, messages);

		if (count == 0) {
			ArrayResize(eventList, 0);
			return 0;
		}

		string keyArray[];
		StringSplit(keys, ',', keyArray);
		trimKeyArray(keyArray);

		ArrayResize(eventList, 0);
		int matched = 0;

		for (int i = 0; i < count; i++) {
			JSON::Object *payload = new JSON::Object(messages[i].payloadJson);
			string eventKey = payload.getString("key");

			bool isMatch = matchesKey(eventKey, keyArray) && matchesFilters(payload, symbolFilter, strategyFilter);

			if (isMatch && matched < limit) {
				SGatewayEvent event;
				event.FromJson(payload);

				ArrayResize(eventList, matched + 1);
				eventList[matched] = event;
				matched++;

				SEMessageBus::Ack(MB_CHANNEL_EVENTS_IN, messages[i].sequence);
			}

			delete payload;
		}

		return matched;
	}

	bool ackEventViaBus(const string eventId, JSON::Object &responseBody) {
		JSON::Object payload;
		payload.setProperty("event_id", eventId);

		string responseJson = responseBody.toString();
		JSON::Object *responseCopy = new JSON::Object(responseJson);
		payload.setProperty("response", responseCopy);

		return SEMessageBus::Send(MB_CHANNEL_EVENTS_OUT, "ack_event", payload);
	}

	bool authenticate(string baseUrl, string email, string password) {
		context.DeleteRequest();

		SERequest authRequest(baseUrl);
		authRequest.AddHeader("Content-Type", "application/json");

		JSON::Object loginBody;
		loginBody.setProperty("email", email);
		loginBody.setProperty("password", password);

		SRequestResponse response = authRequest.Post("api/v1/auth/login", loginBody);

		if (response.status != 200) {
			logger.Error(StringFormat("Authentication failed with status %d", response.status));
			return false;
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Error("Authentication response missing 'data' object");
			return false;
		}

		JSON::Object *dataObject = root.getObject("data");
		string accessToken = dataObject.getString("access");

		if (accessToken == "") {
			logger.Error("Authentication response missing 'access' token");
			return false;
		}

		SERequest *authenticatedRequest = new SERequest(baseUrl);
		authenticatedRequest.AddHeader("Content-Type", "application/json");
		authenticatedRequest.AddHeader("Authorization", "Bearer " + accessToken);
		context.SetRequest(authenticatedRequest);

		logger.Info("Authentication successful");
		return true;
	}

public:
	HorizonGateway() {
		events = NULL;
		logger.SetPrefix("HorizonGateway");
	}

	~HorizonGateway() {
		SAFE_DELETE(events);
		context.DeleteRequest();
	}

	bool Initialize(string baseUrl, string email, string password, bool enabled) {
		if (!enabled) {
			return true;
		}

		if (email == "" || password == "") {
			logger.Error("Email and password are required. HorizonGateway integration disabled.");
			return false;
		}

		if (!authenticate(baseUrl, email, password)) {
			return false;
		}

		context.Enable();
		events = new EventResource(GetPointer(context));

		logger.Info("Initialized");
		return true;
	}

	bool IsEnabled() {
		return context.IsEnabled();
	}

	string GetAccountUuid() {
		return context.GetAccountUuid();
	}

	void SetAccountUuid(string uuid) {
		context.SetAccountUuid(uuid);
	}

	bool UpsertAccount() {
		if (!context.IsEnabled()) {
			return false;
		}

		string accountUuid = GetDeterministicAccountUuid(account.GetNumber(), account.GetBrokerServer());

		JSON::Object body;
		body.setProperty("id", accountUuid);
		body.setProperty("account_number", account.GetNumber());
		body.setProperty("broker_server", account.GetBrokerServer());
		body.setProperty("broker_name", account.GetBrokerName());
		body.setProperty("currency", account.GetCurrency());

		SRequestResponse response = context.Post("api/v1/account", body);

		if (response.status != 200 && response.status != 201) {
			logger.Error(StringFormat("Account upsert failed with status %d", response.status));
			return false;
		}

		context.SetAccountUuid(accountUuid);
		logger.Info(StringFormat("Account registered | uuid: %s", accountUuid));

		return true;
	}

	string UpsertAsset(string symbolName) {
		if (!context.IsEnabled()) {
			return "";
		}

		string assetUuid = GetDeterministicAssetUuid(account.GetNumber(), account.GetBrokerServer(), symbolName);

		JSON::Object body;
		body.setProperty("id", assetUuid);
		body.setProperty("account_number", account.GetNumber());
		body.setProperty("broker_server", account.GetBrokerServer());
		body.setProperty("name", symbolName);
		body.setProperty("symbol", symbolName);

		context.Post("api/v1/asset", body);

		registerAsset(symbolName, assetUuid);
		logger.Info(StringFormat("Asset registered | %s | uuid: %s", symbolName, assetUuid));

		return assetUuid;
	}

	string UpsertStrategy(string strategyName, string symbol, string prefix, ulong magicNumber) {
		if (!context.IsEnabled()) {
			return "";
		}

		string strategyUuid = GetDeterministicStrategyUuid(account.GetNumber(), account.GetBrokerServer(), symbol, prefix, strategyName);

		JSON::Object body;
		body.setProperty("id", strategyUuid);
		body.setProperty("account_number", account.GetNumber());
		body.setProperty("broker_server", account.GetBrokerServer());
		body.setProperty("symbol", symbol);
		body.setProperty("prefix", prefix);
		body.setProperty("name", strategyName);
		body.setProperty("magic_number", (long)magicNumber);

		context.Post("api/v1/strategy", body);

		registerStrategy(magicNumber, strategyUuid);
		logger.Info(StringFormat("Strategy registered | %s | magic: %llu | uuid: %s", strategyName, magicNumber, strategyUuid));

		return strategyUuid;
	}

	string GetAssetUuid(string symbolName) {
		for (int i = 0; i < ArraySize(registeredAssets); i++) {
			if (registeredAssets[i].GetSymbol() == symbolName) {
				return registeredAssets[i].GetUuid();
			}
		}

		return "";
	}

	string GetStrategyUuid(ulong magicNumber) {
		for (int i = 0; i < ArraySize(registeredStrategies); i++) {
			if (registeredStrategies[i].GetMagicNumber() == magicNumber) {
				return registeredStrategies[i].GetUuid();
			}
		}

		return "";
	}

	string FetchAccountStatus() {
		if (!context.IsEnabled()) {
			return "active";
		}

		string accountUuid = context.GetAccountUuid();

		if (accountUuid == "") {
			logger.Warning("No account UUID set, assuming active");
			return "active";
		}

		string path = StringFormat("api/v1/account/%s", accountUuid);
		SRequestResponse response = context.Get(path);

		if (response.status != 200 || response.body == "") {
			logger.Warning("Fetch account failed, assuming active");
			return "active";
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Warning("Fetch response missing 'data', assuming active");
			return "active";
		}

		JSON::Object *dataObject = root.getObject("data");
		string status = dataObject.getString("status");

		logger.Info(StringFormat("Account status: %s", status));
		return status;
	}

	string UploadMedia(string fileName, char &fileData[], string contentType = "text/csv") {
		if (!context.IsEnabled()) {
			return "";
		}

		string accountUuid = context.GetAccountUuid();

		if (accountUuid == "") {
			logger.Error("Cannot upload file: account UUID is not set");
			return "";
		}

		string path = StringFormat("api/v1/account/%s/media/upload", accountUuid);
		SRequestResponse response = context.PostMultipart(path, "file", fileName, fileData, contentType);

		if (response.status != 201) {
			logger.Error(StringFormat("Upload failed with status %d for file %s", response.status, fileName));
			return "";
		}

		string body = response.body;
		StringReplace(body, "\\/", "/");

		JSON::Object root(body);

		if (!root.isObject("data")) {
			logger.Error(StringFormat("Upload response missing 'data' | body=%s", body));
			return "";
		}

		JSON::Object *dataObject = root.getObject("data");
		return dataObject.getString("file_name");
	}

	int ConsumeEvents(const string keys, const string symbolFilter, SGatewayEvent &eventList[], int limit = 10, int strategyFilter = 0, bool async = true) {
		if (!context.IsEnabled()) {
			return 0;
		}

		if (async && SEMessageBus::IsActive()) {
			return consumeEventsFromBus(keys, symbolFilter, eventList, limit, strategyFilter);
		}

		return events.Consume(keys, symbolFilter, eventList, limit, strategyFilter);
	}

	bool AckEvent(const string eventId, JSON::Object &responseBody, bool async = true) {
		if (!context.IsEnabled()) {
			return false;
		}

		if (async && SEMessageBus::IsActive()) {
			return ackEventViaBus(eventId, responseBody);
		}

		return events.Ack(eventId, responseBody);
	}

	bool AckEventDirect(const string eventId, JSON::Object &responseBody) {
		if (!context.IsEnabled()) {
			return false;
		}

		return events.Ack(eventId, responseBody);
	}
};

#endif
