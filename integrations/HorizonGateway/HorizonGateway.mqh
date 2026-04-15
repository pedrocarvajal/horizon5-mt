#ifndef __HORIZON_GATEWAY_MQH__
#define __HORIZON_GATEWAY_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../services/SEMessageBus/SEMessageBus.mqh"
#include "../../constants/COMessageBus.mqh"

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

	bool matchesFilters(JSON::Object *payload, const string symbolFilter, const string strategyFilter) {
		if (strategyFilter != "") {
			string eventStrategy = payload.getString("strategy_id");
			if (eventStrategy != "" && eventStrategy != strategyFilter) {
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

	int consumeEventsFromBus(const string keys, const string symbolFilter, SGatewayEvent &eventList[], int limit, const string strategyFilter) {
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
			logger.Error(
				LOG_CODE_REMOTE_AUTH_FAILED,
				StringFormat(
					"auth failed | status=%d",
					response.status
			));
			return false;
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Error(
				LOG_CODE_REMOTE_RESPONSE_INVALID,
				"auth response invalid | reason='missing data object'"
			);
			return false;
		}

		JSON::Object *dataObject = root.getObject("data");
		string accessToken = dataObject.getString("access");

		if (accessToken == "") {
			logger.Error(
				LOG_CODE_REMOTE_RESPONSE_INVALID,
				"auth response invalid | reason='missing access token'"
			);
			return false;
		}

		SERequest *authenticatedRequest = new SERequest(baseUrl);
		authenticatedRequest.AddHeader("Content-Type", "application/json");
		authenticatedRequest.AddHeader("Authorization", "Bearer " + accessToken);
		context.SetRequest(authenticatedRequest);

		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			"Authentication successful"
		);
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
			if (context.IsEnabled()) {
				SAFE_DELETE(events);
				context.Disable();
			}
			return true;
		}

		if (email == "" || password == "") {
			logger.Error(
				LOG_CODE_CONFIG_INVALID_PARAMETER,
				"configuration invalid | integration=gateway field=credentials reason='email and password required'"
			);
			return false;
		}

		if (context.IsEnabled()) {
			SAFE_DELETE(events);
			context.Disable();
		}

		if (!authenticate(baseUrl, email, password)) {
			return false;
		}

		context.Enable();
		events = new EventResource(GetPointer(context));

		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			"Initialized"
		);
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
			logger.Error(
				LOG_CODE_REMOTE_HTTP_ERROR,
				StringFormat(
					"account upsert failed | status=%d",
					response.status
			));
			return false;
		}

		context.SetAccountUuid(accountUuid);
		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"Account registered | uuid: %s",
				accountUuid
		));

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
		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"Asset registered | %s | uuid: %s",
				symbolName,
				assetUuid
		));

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
		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"Strategy registered | %s | magic: %llu | uuid: %s",
				strategyName,
				magicNumber,
				strategyUuid
		));

		return strategyUuid;
	}

	void PublishNotification(const string notificationType, const string strategyUuid, const string assetUuid, const string symbolName, JSON::Object *payload) {
		if (payload == NULL) {
			return;
		}

		if (!context.IsEnabled()) {
			delete payload;
			return;
		}

		string accountUuid = context.GetAccountUuid();

		if (accountUuid == "") {
			logger.Warning(
				LOG_CODE_CONFIG_MISSING_DEPENDENCY,
				"publish notification skipped | reason='no account uuid'"
			);
			delete payload;
			return;
		}

		JSON::Object body;
		body.setProperty("type", notificationType);

		if (strategyUuid != "") {
			body.setProperty("strategy_id", strategyUuid);
		}

		if (assetUuid != "") {
			body.setProperty("asset_id", assetUuid);
		}

		if (symbolName != "") {
			body.setProperty("symbol", symbolName);
		}

		body.setProperty("payload", payload);

		string path = StringFormat("api/v1/account/%s/notification", accountUuid);
		SRequestResponse response = context.Post(path, body);

		if (response.status != 200 && response.status != 201) {
			logger.Warning(
				LOG_CODE_REMOTE_HTTP_ERROR,
				StringFormat(
					"publish notification failed | type=%s status=%d symbol=%s",
					notificationType,
					response.status,
					symbolName
			));
		}
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
			logger.Warning(
				LOG_CODE_REMOTE_RESPONSE_INVALID,
				"account status unknown | reason='no account uuid' assumed=active"
			);
			return "active";
		}

		string path = StringFormat("api/v1/account/%s", accountUuid);
		SRequestResponse response = context.Get(path);

		if (response.status != 200 || response.body == "") {
			logger.Warning(
				LOG_CODE_REMOTE_HTTP_ERROR,
				"account status unknown | reason='fetch failed' assumed=active"
			);
			return "active";
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Warning(
				LOG_CODE_REMOTE_RESPONSE_INVALID,
				"account status unknown | reason='missing data' assumed=active"
			);
			return "active";
		}

		JSON::Object *dataObject = root.getObject("data");
		string status = dataObject.getString("status");

		logger.Info(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"Account status: %s",
				status
		));
		return status;
	}

	string UploadMedia(string fileName, char &fileData[], string contentType = "text/csv") {
		if (!context.IsEnabled()) {
			return "";
		}

		string accountUuid = context.GetAccountUuid();

		if (accountUuid == "") {
			logger.Error(
				LOG_CODE_CONFIG_MISSING_DEPENDENCY,
				"file upload failed | reason='account uuid not set'"
			);
			return "";
		}

		string path = StringFormat("api/v1/account/%s/media/upload", accountUuid);
		SRequestResponse response = context.PostMultipart(path, "file", fileName, fileData, contentType);

		if (response.status != 201) {
			logger.Error(
				LOG_CODE_REMOTE_HTTP_ERROR,
				StringFormat(
					"file upload failed | status=%d file=%s",
					response.status,
					fileName
			));
			return "";
		}

		string body = response.body;
		StringReplace(body, "\\/", "/");

		JSON::Object root(body);

		if (!root.isObject("data")) {
			logger.Error(
				LOG_CODE_REMOTE_RESPONSE_INVALID,
				StringFormat(
					"upload response invalid | reason='missing data' body=%s",
					body
			));
			return "";
		}

		JSON::Object *dataObject = root.getObject("data");
		return dataObject.getString("file_name");
	}

	int ConsumeEvents(const string keys, const string symbolFilter, SGatewayEvent &eventList[], int limit = 10, const string strategyFilter = "", bool async = true) {
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
