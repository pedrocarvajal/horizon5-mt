#ifndef __SR_REPORT_OF_MONITOR_SEED_MQH__
#define __SR_REPORT_OF_MONITOR_SEED_MQH__

#include "../../helpers/HGetReportsPath.mqh"
#include "../../helpers/HGenerateDeterministicUuid.mqh"
#include "../../helpers/HGetAccountUuid.mqh"
#include "../../helpers/HGetAssetUuid.mqh"
#include "../../helpers/HGetStrategyUuid.mqh"
#include "../../helpers/HGetOrderUuid.mqh"
#include "../../helpers/HClampNumeric.mqh"
#include "../../helpers/HGetOrderSide.mqh"
#include "../../helpers/HGetOrderStatus.mqh"
#include "../../helpers/HGetCloseReason.mqh"
#include "../../helpers/HGetSnapshotEvent.mqh"
#include "../../helpers/HGetAssetRate.mqh"

#include "../../entities/EAccount.mqh"
#include "../../entities/EAsset.mqh"
#include "../../entities/EOrder.mqh"

#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"

#define MONITOR_SEED_MIN_TIMESTAMP 1577836800
#define MONITOR_SEED_MAX_TIMESTAMP 4102444800

class SRReportOfMonitorSeed {
private:
	SELogger logger;
	SEDb database;
	EAccount account;

	SEDbCollection *accountsCollection;
	SEDbCollection *assetsCollection;
	SEDbCollection *strategiesCollection;
	SEDbCollection *ordersCollection;
	SEDbCollection *accountMetadataCollection;
	SEDbCollection *assetMetadataCollection;

	SEDbCollection *accountSnapshotsCollection;
	SEDbCollection *assetSnapshotsCollection;
	SEDbCollection *strategySnapshotsCollection;
	string reportsDir;
	string accountUuid;

	string assetSymbols[];
	string assetUuids[];

	ulong strategyMagics[];
	string strategyUuids[];

	string getAssetUuid(string symbolName) {
		for (int i = 0; i < ArraySize(assetSymbols); i++) {
			if (assetSymbols[i] == symbolName) {
				return assetUuids[i];
			}
		}

		return "";
	}

	string getStrategyUuid(ulong magicNumber) {
		for (int i = 0; i < ArraySize(strategyMagics); i++) {
			if (strategyMagics[i] == magicNumber) {
				return strategyUuids[i];
			}
		}

		return "";
	}

	bool isValidTimestamp(long timestamp) {
		return timestamp >= MONITOR_SEED_MIN_TIMESTAMP && timestamp <= MONITOR_SEED_MAX_TIMESTAMP;
	}

	JSON::Object *buildAccountJson() {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("id", accountUuid);
		obj.setProperty("account_number", account.GetNumber());
		obj.setProperty("broker_server", account.GetBrokerServer());
		obj.setProperty("broker_name", account.GetBrokerName());
		obj.setProperty("currency", account.GetCurrency());
		obj.setProperty("status", "active");

		return obj;
	}

	JSON::Object *buildAssetJson(string symbolName, string assetUuid) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("id", assetUuid);
		obj.setProperty("account_id", accountUuid);
		obj.setProperty("name", symbolName);
		obj.setProperty("symbol", symbolName);

		return obj;
	}

	JSON::Object *buildStrategyJson(string strategyName, string symbolName, string strategyPrefix, ulong magicNumber, string strategyUuid) {
		string assetId = getAssetUuid(symbolName);

		JSON::Object *obj = new JSON::Object();
		obj.setProperty("id", strategyUuid);
		obj.setProperty("account_id", accountUuid);
		obj.setProperty("asset_id", assetId);
		obj.setProperty("prefix", strategyPrefix);
		obj.setProperty("name", strategyName);
		obj.setProperty("magic_number", (long)magicNumber);

		return obj;
	}

	JSON::Object *buildOrderJson(EOrder &order) {
		long accountNumber = account.GetNumber();
		string brokerServer = account.GetBrokerServer();
		string orderUuid = GetDeterministicOrderUuid(
			accountNumber, brokerServer, order.GetSymbol(),
			order.GetMagicNumber(), order.GetOrderId(), order.GetPositionId()
		);
		string strategyId = getStrategyUuid(order.GetMagicNumber());
		string assetId = getAssetUuid(order.GetSymbol());

		JSON::Object *obj = new JSON::Object();
		obj.setProperty("id", orderUuid);
		obj.setProperty("account_id", accountUuid);
		obj.setProperty("strategy_id", strategyId);
		obj.setProperty("asset_id", assetId);
		obj.setProperty("deal_id", (long)order.GetDealId());
		obj.setProperty("order_id", (long)order.GetOrderId());
		obj.setProperty("position_id", (long)order.GetPositionId());
		obj.setProperty("source", order.GetSource());
		obj.setProperty("side", GetOrderSide(order.GetSide()));
		obj.setProperty("status", GetOrderStatus(order.GetStatus()));
		obj.setProperty("is_market_order", order.IsMarketOrder());
		obj.setProperty("volume", ClampNumeric(order.GetVolume(), 6, 4));
		obj.setProperty("signal_price", ClampNumeric(order.GetSignalPrice(), 10, 5));
		obj.setProperty("open_at_price", ClampNumeric(order.GetOpenAtPrice(), 10, 5));
		obj.setProperty("open_price", ClampNumeric(order.GetOpenPrice(), 10, 5));
		obj.setProperty("close_price", ClampNumeric(order.GetClosePrice(), 10, 5));
		obj.setProperty("take_profit", ClampNumeric(order.GetTakeProfitPrice(), 10, 5));
		obj.setProperty("stop_loss", ClampNumeric(order.GetStopLossPrice(), 10, 5));
		obj.setProperty("profit", ClampNumeric(order.GetProfitInDollars(), 13, 2));
		obj.setProperty("gross_profit", ClampNumeric(order.GetGrossProfit(), 13, 2));
		obj.setProperty("commission", ClampNumeric(order.GetCommission(), 13, 2));
		obj.setProperty("swap", ClampNumeric(order.GetSwap(), 13, 2));
		obj.setProperty("close_reason", GetCloseReason(order.GetCloseReason()));

		long signalAt = (long)order.GetSignalAt().timestamp;
		long openedAt = (long)order.GetOpenAt().timestamp;
		long closedAt = (long)order.GetCloseAt().timestamp;

		if (isValidTimestamp(signalAt)) {
			obj.setProperty("signal_at", signalAt);
		}

		if (isValidTimestamp(openedAt)) {
			obj.setProperty("opened_at", openedAt);
		}

		if (isValidTimestamp(closedAt)) {
			obj.setProperty("closed_at", closedAt);
		}

		return obj;
	}

	JSON::Object *buildMetadataEntryJson(string parentId, string parentType, string key, string label, string value, string format) {
		string metadataUuid = GenerateDeterministicUuid(
			StringFormat("%s:%s:%s", parentType, parentId, key)
		);

		JSON::Object *obj = new JSON::Object();
		obj.setProperty("id", metadataUuid);

		if (parentType == "account_metadata") {
			obj.setProperty("account_id", parentId);
		} else {
			obj.setProperty("asset_id", parentId);
		}

		obj.setProperty("key", key);
		obj.setProperty("label", label);
		obj.setProperty("value", value);
		obj.setProperty("format", format);

		return obj;
	}

	JSON::Object *buildAccountSnapshotJson(double balance, double equity, double margin, double floatingPnl, double realizedPnl, ENUM_SNAPSHOT_EVENT event, long timestamp) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("account_id", accountUuid);
		obj.setProperty("balance", ClampNumeric(balance, 13, 2));
		obj.setProperty("equity", ClampNumeric(equity, 13, 2));
		obj.setProperty("margin", ClampNumeric(margin, 13, 2));
		obj.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		obj.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
		obj.setProperty("event", GetSnapshotEvent(event));
		obj.setProperty("created_at", timestamp);

		return obj;
	}

	JSON::Object *buildAssetSnapshotJson(string assetId, double balance, double equity, double floatingPnl, double realizedPnl, double bid, double ask, double usdRate, ENUM_SNAPSHOT_EVENT event, long timestamp) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("asset_id", assetId);
		obj.setProperty("balance", ClampNumeric(balance, 13, 2));
		obj.setProperty("equity", ClampNumeric(equity, 13, 2));
		obj.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		obj.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
		obj.setProperty("bid", ClampNumeric(bid, 10, 5));
		obj.setProperty("ask", ClampNumeric(ask, 10, 5));
		obj.setProperty("usd_rate", ClampNumeric(usdRate, 7, 8));
		obj.setProperty("event", GetSnapshotEvent(event));
		obj.setProperty("created_at", timestamp);

		return obj;
	}

	JSON::Object *buildStrategySnapshotJson(string strategyId, double balance, double equity, double floatingPnl, double realizedPnl, ENUM_SNAPSHOT_EVENT event, long timestamp) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("account_id", accountUuid);
		obj.setProperty("strategy_id", strategyId);
		obj.setProperty("balance", ClampNumeric(balance, 13, 2));
		obj.setProperty("equity", ClampNumeric(equity, 13, 2));
		obj.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		obj.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
		obj.setProperty("event", GetSnapshotEvent(event));
		obj.setProperty("created_at", timestamp);

		return obj;
	}

	void insertAndDelete(SEDbCollection *collection, JSON::Object *json) {
		collection.InsertOne(json);
		delete json;
	}

	void extractMetadataEntries(JSON::Array *entries, string parentId, string parentType, SEDbCollection *collection) {
		for (int i = 0; i < entries.getLength(); i++) {
			JSON::Object *entry = entries.getObject(i);

			if (entry == NULL) {
				continue;
			}

			string key = entry.getString("key");
			string label = entry.getString("label");
			string value = entry.getString("value");
			string format = entry.getString("format");

			JSON::Object *metaJson = buildMetadataEntryJson(parentId, parentType, key, label, value, format);
			collection.InsertOne(metaJson);
			delete metaJson;
		}
	}

public:
	SRReportOfMonitorSeed() {
		logger.SetPrefix("MonitorSeedReporter");
	}

	void Initialize(string symbol, string reportName) {
		reportsDir = REPORTS_PATH;
		database.Initialize(reportsDir, true);

		accountsCollection = database.Collection("accounts");
		accountsCollection.SetAutoFlush(false);

		assetsCollection = database.Collection("assets");
		assetsCollection.SetAutoFlush(false);

		strategiesCollection = database.Collection("strategies");
		strategiesCollection.SetAutoFlush(false);

		ordersCollection = database.Collection("orders");
		ordersCollection.SetAutoFlush(false);

		accountMetadataCollection = database.Collection("account_metadata");
		accountMetadataCollection.SetAutoFlush(false);

		assetMetadataCollection = database.Collection("asset_metadata");
		assetMetadataCollection.SetAutoFlush(false);

		accountSnapshotsCollection = database.Collection("account_snapshots");
		accountSnapshotsCollection.SetAutoFlush(false);

		assetSnapshotsCollection = database.Collection("asset_snapshots");
		assetSnapshotsCollection.SetAutoFlush(false);

		strategySnapshotsCollection = database.Collection("strategy_snapshots");
		strategySnapshotsCollection.SetAutoFlush(false);

		logger.Info(StringFormat("Initialized with report path: %s", reportsDir));
	}

	void RegisterAccount() {
		accountUuid = GetDeterministicAccountUuid(account.GetNumber(), account.GetBrokerServer());

		if (EnableSeedAccounts) {
			insertAndDelete(accountsCollection, buildAccountJson());
		}

		if (EnableSeedMetadata) {
			JSON::Array *metadataEntries = account.GetMetadata();
			extractMetadataEntries(metadataEntries, accountUuid, "account_metadata", accountMetadataCollection);
			delete metadataEntries;
		}

		logger.Info(StringFormat("Registered account %lld -> %s", account.GetNumber(), accountUuid));
	}

	void RegisterAsset(string symbolName) {
		string assetUuid = GetDeterministicAssetUuid(account.GetNumber(), account.GetBrokerServer(), symbolName);

		int index = ArraySize(assetSymbols);
		ArrayResize(assetSymbols, index + 1);
		ArrayResize(assetUuids, index + 1);
		assetSymbols[index] = symbolName;
		assetUuids[index] = assetUuid;

		if (EnableSeedAssets) {
			insertAndDelete(assetsCollection, buildAssetJson(symbolName, assetUuid));
		}

		if (EnableSeedMetadata) {
			int leverage = account.GetLeverage();
			EAsset asset(symbolName);
			JSON::Array *metadataEntries = asset.GetMetadata(leverage);
			extractMetadataEntries(metadataEntries, assetUuid, "asset_metadata", assetMetadataCollection);
			delete metadataEntries;
		}

		logger.Info(StringFormat("Registered asset %s -> %s", symbolName, assetUuid));
	}

	void RegisterStrategy(string strategyName, string symbolName, string strategyPrefix, ulong magicNumber) {
		string strategyUuid = GetDeterministicStrategyUuid(
			account.GetNumber(), account.GetBrokerServer(),
			symbolName, strategyPrefix, strategyName
		);

		int index = ArraySize(strategyMagics);
		ArrayResize(strategyMagics, index + 1);
		ArrayResize(strategyUuids, index + 1);
		strategyMagics[index] = magicNumber;
		strategyUuids[index] = strategyUuid;

		if (EnableSeedStrategies) {
			insertAndDelete(strategiesCollection, buildStrategyJson(strategyName, symbolName, strategyPrefix, magicNumber, strategyUuid));
		}

		logger.Info(StringFormat("Registered strategy %s (%llu) -> %s", strategyName, magicNumber, strategyUuid));
	}

	void AddOrder(EOrder &order) {
		if (!EnableSeedOrders) {
			return;
		}

		insertAndDelete(ordersCollection, buildOrderJson(order));
	}

	void AddAccountSnapshot(double balance, double equity, double margin, double floatingPnl, double realizedPnl, ENUM_SNAPSHOT_EVENT event, long timestamp) {
		if (!EnableSeedSnapshots) {
			return;
		}

		insertAndDelete(accountSnapshotsCollection, buildAccountSnapshotJson(balance, equity, margin, floatingPnl, realizedPnl, event, timestamp));
	}

	void AddAssetSnapshot(string symbolName, double balance, double equity, double floatingPnl, double realizedPnl, double bid, double ask, double usdRate, ENUM_SNAPSHOT_EVENT event, long timestamp) {
		if (!EnableSeedSnapshots) {
			return;
		}

		string assetId = getAssetUuid(symbolName);

		if (assetId == "") {
			return;
		}

		insertAndDelete(assetSnapshotsCollection, buildAssetSnapshotJson(assetId, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate, event, timestamp));
	}

	void AddStrategySnapshot(ulong magicNumber, double balance, double equity, double floatingPnl, double realizedPnl, ENUM_SNAPSHOT_EVENT event, long timestamp) {
		if (!EnableSeedSnapshots) {
			return;
		}

		string strategyId = getStrategyUuid(magicNumber);

		if (strategyId == "") {
			return;
		}

		insertAndDelete(strategySnapshotsCollection, buildStrategySnapshotJson(strategyId, balance, equity, floatingPnl, realizedPnl, event, timestamp));
	}

	void Export() {
		accountsCollection.Flush();
		assetsCollection.Flush();
		strategiesCollection.Flush();
		accountMetadataCollection.Flush();
		assetMetadataCollection.Flush();
		ordersCollection.Flush();
		accountSnapshotsCollection.Flush();
		assetSnapshotsCollection.Flush();
		strategySnapshotsCollection.Flush();

		logger.Info(StringFormat(
			"Monitor seed exported | accounts: %d | assets: %d | strategies: %d | metadata: %d | orders: %d | snapshots: %d",
			accountsCollection.Count(),
			assetsCollection.Count(),
			strategiesCollection.Count(),
			accountMetadataCollection.Count() + assetMetadataCollection.Count(),
			ordersCollection.Count(),
			accountSnapshotsCollection.Count() + assetSnapshotsCollection.Count() + strategySnapshotsCollection.Count()
		));
	}

	string GetCurrentReportsPath() {
		string pathSeparator = "\\";
		string convertedDir = reportsDir;
		StringReplace(convertedDir, "/", pathSeparator);

		return StringFormat("%s%sFiles%s",
			TerminalInfoString(TERMINAL_COMMONDATA_PATH),
			pathSeparator,
			convertedDir
		);
	}
};

#endif
