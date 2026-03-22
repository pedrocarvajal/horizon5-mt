#ifndef __MONITOR_ASSET_RESOURCE_MQH__
#define __MONITOR_ASSET_RESOURCE_MQH__

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetAssetUuid.mqh"

#include "../HorizonMonitorContext.mqh"
#include "../structs/SAssetMapping.mqh"

class AssetResource {
private:
	HorizonMonitorContext * context;
	SELogger logger;

	SAssetMapping registeredAssets[];

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

public:
	AssetResource(HorizonMonitorContext * ctx) {
		context = ctx;
		logger.SetPrefix("Monitor::Asset");
	}

	string GetUuid(string symbolName) {
		for (int i = 0; i < ArraySize(registeredAssets); i++) {
			if (registeredAssets[i].GetSymbol() == symbolName) {
				return registeredAssets[i].GetUuid();
			}
		}

		return "";
	}

	string Upsert(string symbolName) {
		string assetUuid = GetDeterministicAssetUuid(context.GetAccountNumber(), context.GetBrokerServer(), symbolName);

		JSON::Object body;
		body.setProperty("id", assetUuid);
		body.setProperty("account_number", (int)context.GetAccountNumber());
		body.setProperty("broker_server", context.GetBrokerServer());
		body.setProperty("name", symbolName);
		body.setProperty("symbol", symbolName);

		context.Post("api/v1/asset", body, 10000, false);

		registerAsset(symbolName, assetUuid);
		logger.Info(StringFormat("Asset registered | %s | uuid: %s", symbolName, assetUuid));

		return assetUuid;
	}

	void StoreSnapshot(
		string assetUuid,
		double balance,
		double equity,
		double floatingPnl,
		double realizedPnl,
		double bid,
		double ask,
		double usdRate
	) {
		JSON::Object body;
		body.setProperty("asset_id", assetUuid);
		body.setProperty("balance", ClampNumeric(balance, 13, 2));
		body.setProperty("equity", ClampNumeric(equity, 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("realized_pnl", ClampNumeric(realizedPnl, 13, 2));
		body.setProperty("bid", ClampNumeric(bid, 10, 5));
		body.setProperty("ask", ClampNumeric(ask, 10, 5));
		body.setProperty("usd_rate", ClampNumeric(usdRate, 7, 8));

		context.Post("api/v1/assets/snapshots", body);
	}
};

#endif
