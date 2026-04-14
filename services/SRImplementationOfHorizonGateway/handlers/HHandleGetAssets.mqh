#ifndef __H_HANDLE_GATEWAY_GET_ASSETS_MQH__
#define __H_HANDLE_GATEWAY_GET_ASSETS_MQH__

class SEAsset;

void HandleGetAssets(SGatewayEvent &event, HorizonGateway &gateway, SEAsset *&registeredAssets[], SELogger &eventLogger) {
	eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat("Event received | %s | id=%s", event.key, event.id));

	JSON::Object ackBody;
	SEventResponse response;
	response.Success();
	response.ApplyTo(ackBody);

	JSON::Array *assetsArray = new JSON::Array();

	for (int i = 0; i < ArraySize(registeredAssets); i++) {
		if (!registeredAssets[i].IsEnabled()) {
			continue;
		}

		string assetSymbol = registeredAssets[i].GetSymbol();

		JSON::Object *assetEntry = new JSON::Object();
		assetEntry.setProperty("id", gateway.GetAssetUuid(assetSymbol));
		assetEntry.setProperty("name", assetSymbol);
		assetEntry.setProperty("symbol", assetSymbol);
		assetsArray.add(assetEntry);
	}

	ackBody.setProperty("assets", assetsArray);

	eventLogger.Info(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat("Event ack | %s | id=%s", event.key, event.id));
	gateway.AckEvent(event.id, ackBody);
}

#endif
