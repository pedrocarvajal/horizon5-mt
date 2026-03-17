#ifndef __SR_IMPLEMENTATION_OF_HORIZON_API_MQH__
#define __SR_IMPLEMENTATION_OF_HORIZON_API_MQH__

#include "../SELogger/SELogger.mqh"
#include "../SEMessageBus/SEMessageBus.mqh"
#include "../SEMessageBus/SEMessageBusChannels.mqh"

#include "../../integrations/HorizonAPI/HorizonAPI.mqh"
#include "../../integrations/HorizonAPI/structs/SEventResponse.mqh"
#include "../../structs/STradingStatus.mqh"
#include "../../helpers/HClampNumeric.mqh"
#include "../../helpers/HMapTimeframe.mqh"

#include "handlers/HAckServiceEventError.mqh"
#include "handlers/HHandleGetAccountInfo.mqh"
#include "handlers/HHandleGetTicker.mqh"
#include "handlers/HHandleGetKlines.mqh"
#include "handlers/HHandlePatchAccountDisable.mqh"
#include "handlers/HHandlePatchAccountEnable.mqh"

extern STradingStatus tradingStatus;

class SEAsset;

class SRImplementationOfHorizonAPI {
private:
	HorizonAPI * horizonAPI;
	SELogger logger;

public:
	SRImplementationOfHorizonAPI() {
		horizonAPI = NULL;
		logger.SetPrefix("HorizonAPIImpl");
	}

	void Initialize(HorizonAPI *api) {
		horizonAPI = api;
	}

	void ProcessServiceEvents() {
		SMessage messages[];
		int count = SEMessageBus::Poll(MB_CHANNEL_EVENTS_SERVICE, messages);

		for (int i = 0; i < count; i++) {
			JSON::Object *payload = new JSON::Object(messages[i].payloadJson);
			SHorizonEvent event;
			event.FromJson(payload);
			delete payload;

			if (event.key == "get.account.info") {
				HandleGetAccountInfo(event, *horizonAPI, logger);
			} else if (event.key == "get.ticker") {
				HandleGetTicker(event, *horizonAPI, logger);
			} else if (event.key == "get.klines") {
				HandleGetKlines(event, *horizonAPI, logger);
			} else if (event.key == "patch.account.disable") {
				HandlePatchAccountDisable(event, *horizonAPI, logger, tradingStatus);
			} else if (event.key == "patch.account.enable") {
				HandlePatchAccountEnable(event, *horizonAPI, logger, tradingStatus);
			}

			SEMessageBus::Ack(MB_CHANNEL_EVENTS_SERVICE, messages[i].sequence);
		}
	}

	void SyncAccount(SEAsset *&registeredAssets[], int assetCount) {
		horizonAPI.UpsertAccount();

		double totalDrawdownPct = 0;
		double totalDailyPnl = 0;
		double totalFloatingPnl = 0;
		int totalOpenOrderCount = 0;
		double totalExposureLots = 0;
		double totalExposureUsd = 0;

		for (int i = 0; i < assetCount; i++) {
			registeredAssets[i].SyncToHorizonAPI();
			registeredAssets[i].AggregateSnapshotData(
				totalDrawdownPct,
				totalDailyPnl,
				totalFloatingPnl,
				totalOpenOrderCount,
				totalExposureLots,
				totalExposureUsd
			);
		}

		horizonAPI.StoreAccountSnapshot(
			totalDrawdownPct,
			totalDailyPnl,
			totalFloatingPnl,
			totalOpenOrderCount,
			totalExposureLots,
			totalExposureUsd
		);
	}
};

#endif
