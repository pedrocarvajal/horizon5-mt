#ifndef __SR_IMPLEMENTATION_OF_HORIZON_GATEWAY_MQH__
#define __SR_IMPLEMENTATION_OF_HORIZON_GATEWAY_MQH__

#include "../SELogger/SELogger.mqh"

#include "../SEMessageBus/SEMessageBus.mqh"

#include "../../constants/COMessageBus.mqh"

#include "../../integrations/HorizonGateway/HorizonGateway.mqh"
#include "../../integrations/HorizonGateway/structs/SEventResponse.mqh"

#include "../../structs/STradingStatus.mqh"

#include "../../helpers/HClampNumeric.mqh"
#include "../../helpers/HMapTimeframe.mqh"

#include "handlers/HAckServiceEventError.mqh"
#include "handlers/HHandleGetAccountInfo.mqh"
#include "handlers/HHandleGetTicker.mqh"
#include "handlers/HHandleGetKlines.mqh"
#include "handlers/HHandleGetAssets.mqh"
#include "handlers/HHandleGetStrategies.mqh"
#include "handlers/HHandlePatchAccountDisable.mqh"
#include "handlers/HHandlePatchAccountEnable.mqh"

extern STradingStatus tradingStatus;

class SRImplementationOfHorizonGateway {
private:
	HorizonGateway gateway;
	SELogger logger;

public:
	SRImplementationOfHorizonGateway() {
		logger.SetPrefix("GatewayEvents");
	}

	bool Initialize(string baseUrl, string email, string password, bool enabled) {
		return gateway.Initialize(baseUrl, email, password, enabled);
	}

	bool IsEnabled() {
		return gateway.IsEnabled();
	}

	string GetAccountUuid() {
		return gateway.GetAccountUuid();
	}

	bool UpsertAccount() {
		return gateway.UpsertAccount();
	}

	string UpsertAsset(string symbolName) {
		return gateway.UpsertAsset(symbolName);
	}

	string UpsertStrategy(string strategyName, string symbol, string prefix, ulong magicNumber) {
		return gateway.UpsertStrategy(strategyName, symbol, prefix, magicNumber);
	}

	string GetAssetUuid(string symbolName) {
		return gateway.GetAssetUuid(symbolName);
	}

	string GetStrategyUuid(ulong magicNumber) {
		return gateway.GetStrategyUuid(magicNumber);
	}

	string FetchAccountStatus() {
		return gateway.FetchAccountStatus();
	}

	int ConsumeEvents(const string keys, const string symbolFilter, SGatewayEvent &eventList[], int limit = 10, const string strategyFilter = "") {
		return gateway.ConsumeEvents(keys, symbolFilter, eventList, limit, strategyFilter);
	}

	bool AckEvent(const string eventId, JSON::Object &responseBody) {
		return gateway.AckEvent(eventId, responseBody);
	}

	bool AckEventDirect(const string eventId, JSON::Object &responseBody) {
		return gateway.AckEventDirect(eventId, responseBody);
	}

	void PublishNotification(const string notificationType, const string strategyUuid, const string assetUuid, const string symbolName, JSON::Object *payload) {
		gateway.PublishNotification(notificationType, strategyUuid, assetUuid, symbolName, payload);
	}

	void ProcessServiceEvents(SEAsset *&registeredAssets[]) {
		SMessage messages[];
		int count = SEMessageBus::Poll(MB_CHANNEL_EVENTS_SERVICE, messages);

		for (int i = 0; i < count; i++) {
			JSON::Object *payload = new JSON::Object(messages[i].payloadJson);
			SGatewayEvent event;
			event.FromJson(payload);
			delete payload;

			if (event.key == "get.account.info") {
				HandleGetAccountInfo(event, gateway, logger);
			} else if (event.key == "get.assets") {
				HandleGetAssets(event, gateway, registeredAssets, logger);
			} else if (event.key == "get.strategies") {
				HandleGetStrategies(event, gateway, registeredAssets, logger);
			} else if (event.key == "get.ticker") {
				HandleGetTicker(event, gateway, logger);
			} else if (event.key == "get.klines") {
				HandleGetKlines(event, gateway, logger);
			} else if (event.key == "patch.account.disable") {
				HandlePatchAccountDisable(event, gateway, logger, tradingStatus);
			} else if (event.key == "patch.account.enable") {
				HandlePatchAccountEnable(event, gateway, logger, tradingStatus);
			}

			SEMessageBus::Ack(MB_CHANNEL_EVENTS_SERVICE, messages[i].sequence);
		}
	}
};

#endif
