#ifndef __SR_REPORT_OF_MONITOR_SEED_MQH__
#define __SR_REPORT_OF_MONITOR_SEED_MQH__

#include "../../helpers/HGetReportsPath.mqh"

#include "../../entities/EAccount.mqh"
#include "../../entities/EOrder.mqh"

#include "../SELogger/SELogger.mqh"

#include "../SEDb/SEDb.mqh"

#include "components/UuidRegistry.mqh"
#include "components/MetadataExporter.mqh"
#include "components/AccountEnroller.mqh"
#include "components/AssetEnroller.mqh"
#include "components/StrategyEnroller.mqh"
#include "components/OrderExporter.mqh"
#include "components/SnapshotExporter.mqh"

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

	UuidRegistry registry;
	MetadataExporter metadataExporter;
	AccountEnroller accountEnroller;
	AssetEnroller assetEnroller;
	StrategyEnroller strategyEnroller;
	OrderExporter orderExporter;
	SnapshotExporter snapshotExporter;

	string reportsDir;
	string accountUuid;

public:
	SRReportOfMonitorSeed() {
		logger.SetPrefix("MonitorSeedReporter");
	}

	void AddAccountSnapshot(
		double balance,
		double equity,
		double margin,
		double floatingPnl,
		double realizedPnl,
		ENUM_SNAPSHOT_EVENT event,
		long timestamp
	) {
		snapshotExporter.ExportAccountSnapshot(
			accountUuid, balance, equity, margin, floatingPnl, realizedPnl, event, timestamp
		);
	}

	void AddAssetSnapshot(
		string symbolName,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		double bid,
		double ask,
		double usdRate,
		ENUM_SNAPSHOT_EVENT event,
		long timestamp
	) {
		snapshotExporter.ExportAssetSnapshot(
			symbolName, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate, event, timestamp
		);
	}

	void AddOrder(EOrder &order) {
		orderExporter.Export(order, account, accountUuid);
	}

	void AddStrategySnapshot(
		ulong magicNumber,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		ENUM_SNAPSHOT_EVENT event,
		long timestamp
	) {
		snapshotExporter.ExportStrategySnapshot(
			accountUuid, magicNumber, balance, equity, floatingPnl, realizedPnl, event, timestamp
		);
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

		logger.Info(LOG_CODE_STATS_EXPORT_FAILED, StringFormat(
			"Monitor seed exported | accounts: %d | assets: %d | strategies: %d | metadata: %d | orders: %d | snapshots: %d",
			accountsCollection.Count(),
			assetsCollection.Count(),
			strategiesCollection.Count(),
			accountMetadataCollection.Count() + assetMetadataCollection.Count(),
			ordersCollection.Count(),
			accountSnapshotsCollection.Count() + assetSnapshotsCollection.Count() + strategySnapshotsCollection.Count()
		));
	}

	void Initialize(string symbol, string reportName) {
		reportsDir = REPORTS_PATH;
		database.Initialize(reportsDir, true);

		initializeCollections();
		initializeComponents();

		logger.Info(LOG_CODE_STATS_EXPORT_FAILED, StringFormat("Initialized with report path: %s", reportsDir));
	}

	void RegisterAccount() {
		accountUuid = accountEnroller.Enroll(account);
	}

	void RegisterAsset(string symbolName) {
		assetEnroller.Enroll(symbolName, account, accountUuid);
	}

	void RegisterStrategy(string strategyName, string symbolName, string strategyPrefix, ulong magicNumber) {
		strategyEnroller.Enroll(strategyName, symbolName, strategyPrefix, magicNumber, account, accountUuid);
	}

private:
	void initializeCollections() {
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
	}

	void initializeComponents() {
		metadataExporter.Initialize(accountMetadataCollection, assetMetadataCollection);
		accountEnroller.Initialize(accountsCollection, GetPointer(metadataExporter));
		assetEnroller.Initialize(assetsCollection, GetPointer(metadataExporter), GetPointer(registry));
		strategyEnroller.Initialize(strategiesCollection, GetPointer(registry));
		orderExporter.Initialize(ordersCollection, GetPointer(registry));
		snapshotExporter.Initialize(
			accountSnapshotsCollection,
			assetSnapshotsCollection,
			strategySnapshotsCollection,
			GetPointer(registry)
		);
	}
};

#endif
