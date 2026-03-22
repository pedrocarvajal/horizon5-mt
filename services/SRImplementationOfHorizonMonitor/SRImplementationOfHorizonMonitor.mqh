#ifndef __SR_IMPLEMENTATION_OF_HORIZON_MONITOR_MQH__
#define __SR_IMPLEMENTATION_OF_HORIZON_MONITOR_MQH__

#include "../SELogger/SELogger.mqh"

#include "../../interfaces/IRemoteLogger.mqh"
#include "../../integrations/HorizonMonitor/HorizonMonitor.mqh"

class SEAsset;

class SRImplementationOfHorizonMonitor:
public IRemoteLogger {
private:
	HorizonMonitor monitor;
	SELogger logger;

public:
	SRImplementationOfHorizonMonitor() {
		logger.SetPrefix("MonitorSync");
	}

	bool Initialize(string baseUrl, string email, string password, bool enabled) {
		return monitor.Initialize(baseUrl, email, password, enabled);
	}

	bool IsEnabled() {
		return monitor.IsEnabled();
	}

	string GetAccountUuid() {
		return monitor.GetAccountUuid();
	}

	string GetAssetUuid(string symbolName) {
		return monitor.GetAssetUuid(symbolName);
	}

	string GetStrategyUuid(ulong magicNumber) {
		return monitor.GetStrategyUuid(magicNumber);
	}

	bool UpsertAccount() {
		return monitor.UpsertAccount();
	}

	void UpsertAccountMetadata() {
		monitor.UpsertAccountMetadata();
	}

	string UpsertAsset(string symbolName) {
		return monitor.UpsertAsset(symbolName);
	}

	void UpsertAssetMetadata(string assetUuid, string symbolName) {
		monitor.UpsertAssetMetadata(assetUuid, symbolName);
	}

	string UpsertStrategy(string strategyName, string symbol, string prefix, ulong magicNumber) {
		return monitor.UpsertStrategy(strategyName, symbol, prefix, magicNumber);
	}

	void UpsertOrder(EOrder &order) {
		monitor.UpsertOrder(order);
	}

	void StoreHeartbeat(ulong magicNumber, ENUM_HEARTBEAT_EVENT event, string systemName = "strategy") {
		monitor.StoreHeartbeat(magicNumber, event, systemName);
	}

	void StoreSystemHeartbeat(ENUM_HEARTBEAT_EVENT event) {
		monitor.StoreSystemHeartbeat(event);
	}

	void StoreLog(string system, string level, string message, ulong magicNumber = 0) {
		monitor.StoreLog(system, level, message, magicNumber);
	}

	void StoreAccountSnapshot(double floatingPnl, double realizedPnl) {
		monitor.StoreAccountSnapshot(floatingPnl, realizedPnl);
	}

	void StoreStrategySnapshot(ulong magicNumber, double balance, double equity, double floatingPnl, double realizedPnl) {
		monitor.StoreStrategySnapshot(magicNumber, balance, equity, floatingPnl, realizedPnl);
	}

	void StoreAssetSnapshot(string assetUuid, double balance, double equity, double floatingPnl, double realizedPnl, double bid, double ask, double usdRate) {
		monitor.StoreAssetSnapshot(assetUuid, balance, equity, floatingPnl, realizedPnl, bid, ask, usdRate);
	}

	void PostDirect(string path, JSON::Object &body) {
		monitor.PostDirect(path, body);
	}

	HorizonMonitor *GetMonitor() {
		return GetPointer(monitor);
	}

	void SyncAccount(SEAsset *&registeredAssets[], int assetCount) {
		monitor.UpsertAccount();
		monitor.UpsertAccountMetadata();

		double totalFloatingPnl = 0;
		double totalRealizedPnl = 0;

		for (int i = 0; i < assetCount; i++) {
			registeredAssets[i].RegisterEntities();
			registeredAssets[i].SyncToMonitor();
			registeredAssets[i].AggregateSnapshotData(
				totalFloatingPnl,
				totalRealizedPnl
			);
		}

		monitor.StoreAccountSnapshot(totalFloatingPnl, totalRealizedPnl);
	}
};

#endif
