#ifndef __MONITOR_ASSET_RESOURCE_MQH__
#define __MONITOR_ASSET_RESOURCE_MQH__

#include "../../../helpers/HClampNumeric.mqh"
#include "../../../helpers/HGetAssetUuid.mqh"
#include "../../../helpers/HGetSnapshotEvent.mqh"

#include "../HorizonMonitorContext.mqh"

#include "../../../services/SERequest/structs/SRequestResponse.mqh"

#include "../structs/SAssetMapping.mqh"

class AssetResource {
private:
	HorizonMonitorContext * context;
	SELogger logger;

	SAssetMapping registeredAssets[];

	bool hasHttpFailed(SRequestResponse &response, const string failurePrefix) {
		if (response.status >= 200 && response.status < 300) {
			return false;
		}

		logger.Error(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"%s status=%d body='%s'",
				failurePrefix,
				response.status,
				response.body
		));

		return true;
	}

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

		SRequestResponse response = context.Post("api/v1/asset", body, false);

		string failurePrefix = StringFormat("asset upsert failed | symbol=%s", symbolName);
		if (hasHttpFailed(response, failurePrefix)) {
			return "";
		}

		registerAsset(symbolName, assetUuid);
		logger.Info(
			LOG_CODE_REMOTE_HTTP_OK,
			StringFormat(
				"asset registered | symbol=%s uuid=%s",
				symbolName,
				assetUuid
		));

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
		double usdRate,
		ENUM_SNAPSHOT_EVENT event
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
		body.setProperty("event", GetSnapshotEvent(event));

		context.Post("api/v1/assets/snapshots", body);
	}
};

#endif
