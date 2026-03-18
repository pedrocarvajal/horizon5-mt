#ifndef __HORIZON_API_MQH__
#define __HORIZON_API_MQH__

#include "../../interfaces/IRemoteLogger.mqh"

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"

#include "../../entities/EOrder.mqh"

#include "HorizonAPIContext.mqh"
#include "resources/AccountResource.mqh"
#include "resources/StrategyResource.mqh"
#include "resources/OrderResource.mqh"
#include "resources/HeartbeatResource.mqh"
#include "resources/LogResource.mqh"
#include "resources/SnapshotResource.mqh"
#include "resources/SymbolResource.mqh"
#include "resources/EventResource.mqh"
#include "resources/MediaResource.mqh"

#define SAFE_DELETE(ptr) if (ptr != NULL && CheckPointer(ptr) == POINTER_DYNAMIC) { delete ptr; } ptr = NULL;

class HorizonAPI:
public IRemoteLogger {
private:
	HorizonAPIContext context;
	SELogger logger;

	AccountResource *accounts;
	StrategyResource *strategies;
	OrderResource *orders;
	HeartbeatResource *heartbeats;
	LogResource *logs;
	SnapshotResource *snapshots;
	SymbolResource *symbols;
	EventResource *events;
	MediaResource *media;

	void resetResources(bool cleanup = false) {
		if (cleanup) {
			SAFE_DELETE(orders);
			SAFE_DELETE(heartbeats);
			SAFE_DELETE(logs);
			SAFE_DELETE(snapshots);
			SAFE_DELETE(symbols);
			SAFE_DELETE(media);
			SAFE_DELETE(events);
			SAFE_DELETE(strategies);
			SAFE_DELETE(accounts);
		} else {
			orders = NULL;
			heartbeats = NULL;
			logs = NULL;
			snapshots = NULL;
			symbols = NULL;
			media = NULL;
			events = NULL;
			strategies = NULL;
			accounts = NULL;
		}
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

	int consumeEventsFromBus(const string keys, const string symbolFilter, SHorizonEvent &eventList[], int limit, int strategyFilter) {
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
				SHorizonEvent event;
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

		SRequestResponse response = authRequest.Post("api/v1/auth/login/", loginBody, 10000);

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

	void initResources() {
		HorizonAPIContext *ctx = GetPointer(context);
		accounts = new AccountResource(ctx);
		strategies = new StrategyResource(ctx);
		orders = new OrderResource(ctx, strategies);
		heartbeats = new HeartbeatResource(ctx, strategies);
		logs = new LogResource(ctx, strategies);
		snapshots = new SnapshotResource(ctx, strategies);
		symbols = new SymbolResource(ctx);
		events = new EventResource(ctx);
		media = new MediaResource(ctx);
	}

public:
	HorizonAPI() {
		resetResources();
		logger.SetPrefix("HorizonAPI");
	}

	~HorizonAPI() {
		resetResources(true);
		context.DeleteRequest();
	}

	bool Initialize(string baseUrl, string email, string password, bool enabled) {
		if (!enabled) {
			return true;
		}

		if (email == "" || password == "") {
			logger.Error("Email and password are required. HorizonAPI integration disabled.");
			return false;
		}

		context.SetAccountId(AccountInfoInteger(ACCOUNT_LOGIN));

		if (!authenticate(baseUrl, email, password)) {
			return false;
		}

		context.Enable();
		initResources();

		logger.Info("Initialized for account " + IntegerToString(context.GetAccountId()));
		return true;
	}

	bool IsEnabled() {
		return context.IsEnabled();
	}

	void PostDirect(string path, JSON::Object &body) {
		if (!context.IsEnabled() || !context.HasRequest()) {
			return;
		}

		context.GetRequest().Post(path, body);
	}

	void UpsertAccount() {
		if (!context.IsEnabled()) {
			return;
		}

		accounts.Upsert();
	}

	SHorizonAccount FetchAccount() {
		SHorizonAccount account;

		if (!context.IsEnabled()) {
			account.status = "active";
			return account;
		}

		return accounts.Fetch();
	}

	void UpsertSymbol(string symbolName) {
		if (!context.IsEnabled()) {
			return;
		}

		symbols.Upsert(symbolName);
	}

	void UpsertStrategy(
		string strategyName,
		string symbol,
		string prefix,
		ulong magicNumber,
		double balance
	) {
		if (!context.IsEnabled()) {
			return;
		}

		strategies.Upsert(strategyName, symbol, prefix, magicNumber, balance);
	}

	void StoreHeartbeat(ulong magicNumber, ENUM_HEARTBEAT_EVENT event, string systemName = "strategy") {
		if (!context.IsEnabled()) {
			return;
		}

		heartbeats.Store(magicNumber, event, systemName);
	}

	void StoreSystemHeartbeat(ENUM_HEARTBEAT_EVENT event) {
		if (!context.IsEnabled()) {
			return;
		}

		heartbeats.StoreSystem(event);
	}

	void UpsertOrder(EOrder &order) {
		if (!context.IsEnabled()) {
			return;
		}

		orders.Upsert(order);
	}

	void StoreLog(string level, string message, ulong magicNumber = 0) {
		if (!context.IsEnabled()) {
			return;
		}

		logs.Store(level, message, magicNumber);
	}

	void StoreAccountSnapshot(
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots,
		double exposureUsd
	) {
		if (!context.IsEnabled()) {
			return;
		}

		snapshots.StoreAccount(drawdownPct, dailyPnl, floatingPnl, openOrderCount, exposureLots, exposureUsd);
	}

	void StoreStrategySnapshot(
		ulong magicNumber,
		double nav,
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots,
		double exposureUsd
	) {
		if (!context.IsEnabled()) {
			return;
		}

		snapshots.StoreStrategy(magicNumber, nav, drawdownPct, dailyPnl, floatingPnl, openOrderCount, exposureLots, exposureUsd);
	}

	int ConsumeEvents(const string keys, const string symbolFilter, SHorizonEvent &eventList[], int limit = 10, int strategyFilter = 0) {
		if (!context.IsEnabled()) {
			return 0;
		}

		if (SEMessageBus::IsActive()) {
			return consumeEventsFromBus(keys, symbolFilter, eventList, limit, strategyFilter);
		}

		return events.Consume(keys, symbolFilter, eventList, limit, strategyFilter);
	}

	bool AckEvent(const string eventId, JSON::Object &responseBody) {
		if (!context.IsEnabled()) {
			return false;
		}

		if (SEMessageBus::IsActive()) {
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

	string UploadMedia(string fileName, char &fileData[], string contentType = "text/csv") {
		if (!context.IsEnabled()) {
			return "";
		}

		return media.Upload(fileName, fileData, contentType);
	}
};

#endif
