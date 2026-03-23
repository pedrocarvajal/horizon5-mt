#ifndef __HORIZON_MONITOR_MQH__
#define __HORIZON_MONITOR_MQH__

#include "../../interfaces/IRemoteLogger.mqh"

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"

#include "../../entities/EOrder.mqh"

#include "HorizonMonitorContext.mqh"
#include "resources/AccountResource.mqh"
#include "resources/AccountMetadataResource.mqh"
#include "resources/AssetResource.mqh"
#include "resources/AssetMetadataResource.mqh"
#include "resources/StrategyResource.mqh"
#include "resources/OrderResource.mqh"
#include "resources/HeartbeatResource.mqh"
#include "resources/LogResource.mqh"
#include "resources/SnapshotResource.mqh"

#define SAFE_DELETE(ptr) if (ptr != NULL && CheckPointer(ptr) == POINTER_DYNAMIC) { delete ptr; } ptr = NULL;

class HorizonMonitor:
public IRemoteLogger {
private:
	HorizonMonitorContext context;
	SELogger logger;

	AccountResource *accounts;
	AccountMetadataResource *accountMetadata;
	AssetResource *assets;
	AssetMetadataResource *assetMetadata;
	StrategyResource *strategies;
	OrderResource *orders;
	HeartbeatResource *heartbeats;
	LogResource *logs;
	SnapshotResource *snapshots;

	void resetResources(bool cleanup = false) {
		if (cleanup) {
			SAFE_DELETE(orders);
			SAFE_DELETE(heartbeats);
			SAFE_DELETE(logs);
			SAFE_DELETE(snapshots);
			SAFE_DELETE(assetMetadata);
			SAFE_DELETE(assets);
			SAFE_DELETE(accountMetadata);
			SAFE_DELETE(strategies);
			SAFE_DELETE(accounts);
		} else {
			orders = NULL;
			heartbeats = NULL;
			logs = NULL;
			snapshots = NULL;
			assetMetadata = NULL;
			assets = NULL;
			accountMetadata = NULL;
			strategies = NULL;
			accounts = NULL;
		}
	}

	bool authenticate(string baseUrl, string email, string password) {
		context.DeleteRequest();

		SERequest authRequest(baseUrl);
		authRequest.AddHeader("Content-Type", "application/json");

		JSON::Object loginBody;
		loginBody.setProperty("email", email);
		loginBody.setProperty("password", password);

		SRequestResponse response = authRequest.Post("api/v1/auth/login", loginBody, 10000);

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
		HorizonMonitorContext *ctx = GetPointer(context);
		accounts = new AccountResource(ctx);
		accountMetadata = new AccountMetadataResource(ctx);
		assets = new AssetResource(ctx);
		assetMetadata = new AssetMetadataResource(ctx);
		strategies = new StrategyResource(ctx);
		orders = new OrderResource(ctx, strategies, assets);
		heartbeats = new HeartbeatResource(ctx, strategies);
		logs = new LogResource(ctx, strategies);
		snapshots = new SnapshotResource(ctx, strategies);
	}

public:
	HorizonMonitor() {
		resetResources();
		logger.SetPrefix("HorizonMonitor");
	}

	~HorizonMonitor() {
		resetResources(true);
		context.DeleteRequest();
	}

	bool Initialize(string baseUrl, string email, string password, bool enabled) {
		if (!enabled) {
			return true;
		}

		if (email == "" || password == "") {
			logger.Error("Email and password are required. HorizonMonitor integration disabled.");
			return false;
		}

		if (context.IsEnabled()) {
			resetResources(true);
			context.Disable();
		}

		context.SetAccountNumber(AccountInfoInteger(ACCOUNT_LOGIN));
		context.SetBrokerServer(AccountInfoString(ACCOUNT_SERVER));

		if (!authenticate(baseUrl, email, password)) {
			return false;
		}

		context.Enable();
		initResources();

		logger.Info("Initialized for account " + IntegerToString(context.GetAccountNumber()));
		return true;
	}

	bool IsEnabled() {
		return context.IsEnabled();
	}

	string GetAccountUuid() {
		return context.GetAccountUuid();
	}

	string GetAssetUuid(string symbolName) {
		if (!context.IsEnabled() || assets == NULL) {
			return "";
		}

		return assets.GetUuid(symbolName);
	}

	string GetStrategyUuid(ulong magicNumber) {
		if (!context.IsEnabled() || strategies == NULL) {
			return "";
		}

		return strategies.GetUuid(magicNumber);
	}

	bool UpsertAccount() {
		if (!context.IsEnabled()) {
			return false;
		}

		return accounts.Upsert();
	}

	void UpsertAccountMetadata() {
		if (!context.IsEnabled()) {
			return;
		}

		accountMetadata.Upsert();
	}

	string UpsertAsset(string symbolName) {
		if (!context.IsEnabled()) {
			return "";
		}

		return assets.Upsert(symbolName);
	}

	void UpsertAssetMetadata(string assetUuid, string symbolName) {
		if (!context.IsEnabled()) {
			return;
		}

		assetMetadata.Upsert(assetUuid, symbolName);
	}

	string UpsertStrategy(
		string strategyName,
		string symbol,
		string prefix,
		ulong magicNumber
	) {
		if (!context.IsEnabled()) {
			return "";
		}

		return strategies.Upsert(strategyName, symbol, prefix, magicNumber);
	}

	void UpsertOrder(EOrder &order) {
		if (!context.IsEnabled()) {
			return;
		}

		orders.Upsert(order);
	}

	void StoreHeartbeat(ulong magicNumber, string systemName = "horizon5") {
		if (!context.IsEnabled()) {
			return;
		}

		heartbeats.Store(magicNumber, systemName);
	}

	void StoreSystemHeartbeat(string systemName) {
		if (!context.IsEnabled()) {
			return;
		}

		heartbeats.StoreSystem(systemName);
	}

	void StoreLog(string system, string level, string message, ulong magicNumber = 0) {
		if (!context.IsEnabled()) {
			return;
		}

		logs.Store(system, level, message, magicNumber);
	}

	void StoreAccountSnapshot(double floatingPnl, double realizedPnl, string event) {
		if (!context.IsEnabled()) {
			return;
		}

		snapshots.StoreAccount(floatingPnl, realizedPnl, event);
	}

	void StoreStrategySnapshot(
		ulong magicNumber,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		string event
	) {
		if (!context.IsEnabled()) {
			return;
		}

		snapshots.StoreStrategy(magicNumber, balance, equity, floatingPnl, realizedPnl, event);
	}

	void StoreAssetSnapshot(
		string assetUuid,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		double bid,
		double ask,
		double usdRate,
		string event
	) {
		if (!context.IsEnabled()) {
			return;
		}

		assets.StoreSnapshot(assetUuid, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate, event);
	}

	void PostDirect(string path, JSON::Object &body) {
		if (!context.IsEnabled() || !context.HasRequest()) {
			return;
		}

		context.GetRequest().Post(path, body);
	}
};

#endif
