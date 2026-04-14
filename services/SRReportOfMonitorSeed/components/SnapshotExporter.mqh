#ifndef __SNAPSHOT_EXPORTER_MQH__
#define __SNAPSHOT_EXPORTER_MQH__

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "../helpers/HBuildAccountSnapshotJson.mqh"
#include "../helpers/HBuildAssetSnapshotJson.mqh"
#include "../helpers/HBuildStrategySnapshotJson.mqh"

#include "UuidRegistry.mqh"

class SnapshotExporter {
private:
	SELogger logger;
	SEDbCollection *accountSnapshotsCollection;
	SEDbCollection *assetSnapshotsCollection;
	SEDbCollection *strategySnapshotsCollection;
	UuidRegistry *registry;

public:
	SnapshotExporter() {
		logger.SetPrefix("MonitorSeed::SnapshotExporter");
		accountSnapshotsCollection = NULL;
		assetSnapshotsCollection = NULL;
		strategySnapshotsCollection = NULL;
		registry = NULL;
	}

	void Initialize(
		SEDbCollection *accountSnapshots,
		SEDbCollection *assetSnapshots,
		SEDbCollection *strategySnapshots,
		UuidRegistry *uuidRegistry
	) {
		accountSnapshotsCollection = accountSnapshots;
		assetSnapshotsCollection = assetSnapshots;
		strategySnapshotsCollection = strategySnapshots;
		registry = uuidRegistry;
	}

	void ExportAccountSnapshot(
		string accountUuid,
		double balance,
		double equity,
		double margin,
		double floatingPnl,
		double realizedPnl,
		ENUM_SNAPSHOT_EVENT event,
		long timestamp
	) {
		if (!EnableSeedSnapshots) {
			return;
		}

		JSON::Object *json = BuildAccountSnapshotJson(
			accountUuid, balance, equity, margin, floatingPnl, realizedPnl, event, timestamp
		);
		accountSnapshotsCollection.InsertOne(json);
		delete json;
	}

	void ExportAssetSnapshot(
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
		if (!EnableSeedSnapshots) {
			return;
		}

		string assetUuid = registry.GetAssetUuid(symbolName);

		if (assetUuid == "") {
			return;
		}

		JSON::Object *json = BuildAssetSnapshotJson(
			assetUuid, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate, event, timestamp
		);
		assetSnapshotsCollection.InsertOne(json);
		delete json;
	}

	void ExportStrategySnapshot(
		string accountUuid,
		ulong magicNumber,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		ENUM_SNAPSHOT_EVENT event,
		long timestamp
	) {
		if (!EnableSeedSnapshots) {
			return;
		}

		string strategyUuid = registry.GetStrategyUuid(magicNumber);

		if (strategyUuid == "") {
			return;
		}

		JSON::Object *json = BuildStrategySnapshotJson(
			accountUuid, strategyUuid, balance, equity, floatingPnl, realizedPnl, event, timestamp
		);
		strategySnapshotsCollection.InsertOne(json);
		delete json;
	}
};

#endif
