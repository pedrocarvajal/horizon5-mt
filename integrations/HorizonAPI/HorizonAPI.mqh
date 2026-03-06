#ifndef __HORIZON_API_MQH__
#define __HORIZON_API_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../entities/EOrder.mqh"
#include "../../interfaces/IRemoteLogger.mqh"
#include "HorizonAPIContext.mqh"
#include "resources/AccountResource.mqh"
#include "resources/StrategyResource.mqh"
#include "resources/OrderResource.mqh"
#include "resources/HeartbeatResource.mqh"
#include "resources/LogResource.mqh"
#include "resources/SnapshotResource.mqh"
#include "resources/EventResource.mqh"
#include "resources/MediaResource.mqh"

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
	EventResource *events;
	MediaResource *media;

	bool authenticate(string baseUrl, string apiKey) {
		if (context.request != NULL && CheckPointer(context.request) == POINTER_DYNAMIC) {
			delete context.request;
			context.request = NULL;
		}

		SERequest authRequest(baseUrl);
		authRequest.AddHeader("Content-Type", "application/json");

		JSON::Object loginBody;
		loginBody.setProperty("api_key", apiKey);

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

		context.request = new SERequest(baseUrl);
		context.request.AddHeader("Content-Type", "application/json");
		context.request.AddHeader("Authorization", "Bearer " + accessToken);

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
		events = new EventResource(ctx);
		media = new MediaResource(ctx);
	}

	void deleteResources() {
		if (orders != NULL && CheckPointer(orders) == POINTER_DYNAMIC) {
			delete orders;
		}
		if (heartbeats != NULL && CheckPointer(heartbeats) == POINTER_DYNAMIC) {
			delete heartbeats;
		}
		if (logs != NULL && CheckPointer(logs) == POINTER_DYNAMIC) {
			delete logs;
		}
		if (snapshots != NULL && CheckPointer(snapshots) == POINTER_DYNAMIC) {
			delete snapshots;
		}
		if (media != NULL && CheckPointer(media) == POINTER_DYNAMIC) {
			delete media;
		}
		if (events != NULL && CheckPointer(events) == POINTER_DYNAMIC) {
			delete events;
		}
		if (strategies != NULL && CheckPointer(strategies) == POINTER_DYNAMIC) {
			delete strategies;
		}
		if (accounts != NULL && CheckPointer(accounts) == POINTER_DYNAMIC) {
			delete accounts;
		}

		orders = NULL;
		heartbeats = NULL;
		logs = NULL;
		snapshots = NULL;
		media = NULL;
		events = NULL;
		strategies = NULL;
		accounts = NULL;
	}

public:
	HorizonAPI() {
		accounts = NULL;
		strategies = NULL;
		orders = NULL;
		heartbeats = NULL;
		logs = NULL;
		snapshots = NULL;
		events = NULL;
		media = NULL;
		logger.SetPrefix("HorizonAPI");
	}

	~HorizonAPI() {
		deleteResources();

		if (context.request != NULL && CheckPointer(context.request) == POINTER_DYNAMIC) {
			delete context.request;
			context.request = NULL;
		}
	}

	bool Initialize(string baseUrl, string apiKey, bool enabled) {
		if (!enabled) {
			return true;
		}

		if (apiKey == "") {
			logger.Error("API key is required. HorizonAPI integration disabled.");
			return false;
		}

		context.SetAccountId(AccountInfoInteger(ACCOUNT_LOGIN));

		if (!authenticate(baseUrl, apiKey)) {
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
		double exposureLots
	) {
		if (!context.IsEnabled()) {
			return;
		}

		snapshots.StoreAccount(drawdownPct, dailyPnl, floatingPnl, openOrderCount, exposureLots);
	}

	void StoreStrategySnapshot(
		ulong magicNumber,
		double nav,
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots
	) {
		if (!context.IsEnabled()) {
			return;
		}

		snapshots.StoreStrategy(magicNumber, nav, drawdownPct, dailyPnl, floatingPnl, openOrderCount, exposureLots);
	}

	int ConsumeEvents(const string keys, const string symbolFilter, SHorizonEvent &eventList[], int limit = 10, int strategyFilter = 0) {
		if (!context.IsEnabled()) {
			return 0;
		}

		return events.Consume(keys, symbolFilter, eventList, limit, strategyFilter);
	}

	bool AckEvent(const string eventId, JSON::Object &responseBody) {
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
