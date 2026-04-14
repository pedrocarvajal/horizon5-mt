#ifndef __H_HANDLE_GATEWAY_GET_STRATEGIES_MQH__
#define __H_HANDLE_GATEWAY_GET_STRATEGIES_MQH__

class SEAsset;

void HandleGetStrategies(SGatewayEvent &event, HorizonGateway &gateway, SEAsset *&registeredAssets[], SELogger &eventLogger) {
	eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat("Event received | %s | id=%s", event.key, event.id));

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);

	JSON::Array *strategiesArray = new JSON::Array();

	for (int i = 0; i < ArraySize(registeredAssets); i++) {
		if (!registeredAssets[i].IsEnabled()) {
			continue;
		}

		for (int j = 0; j < registeredAssets[i].GetStrategyCount(); j++) {
			SEStrategy *strategy = registeredAssets[i].GetStrategyAtIndex(j);

			JSON::Object *strategyEntry = new JSON::Object();
			strategyEntry.setProperty("id", gateway.GetStrategyUuid(strategy.GetMagicNumber()));
			strategyEntry.setProperty("asset_id", gateway.GetAssetUuid(registeredAssets[i].GetSymbol()));
			strategyEntry.setProperty("name", strategy.GetName());
			strategyEntry.setProperty("prefix", strategy.GetPrefix());
			strategyEntry.setProperty("symbol", registeredAssets[i].GetSymbol());
			strategyEntry.setProperty("magic_number", (long)strategy.GetMagicNumber());
			strategiesArray.add(strategyEntry);
		}
	}

	ackBody.setProperty("strategies", strategiesArray);

	eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat("Event ack | %s | id=%s", event.key, event.id));
	gateway.AckEvent(event.id, ackBody);
}

#endif
