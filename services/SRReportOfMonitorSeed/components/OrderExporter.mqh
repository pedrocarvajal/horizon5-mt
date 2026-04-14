#ifndef __ORDER_EXPORTER_MQH__
#define __ORDER_EXPORTER_MQH__

#include "../../../entities/EAccount.mqh"
#include "../../../entities/EOrder.mqh"

#include "../../../helpers/HGetOrderUuid.mqh"
#include "../helpers/HBuildOrderJson.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "UuidRegistry.mqh"

class OrderExporter {
private:
	SELogger logger;
	SEDbCollection *ordersCollection;
	UuidRegistry *registry;

public:
	OrderExporter() {
		logger.SetPrefix("MonitorSeed::OrderExporter");
		ordersCollection = NULL;
		registry = NULL;
	}

	void Initialize(SEDbCollection *orders, UuidRegistry *uuidRegistry) {
		ordersCollection = orders;
		registry = uuidRegistry;
	}

	void Export(EOrder &order, EAccount &tradingAccount, string accountUuid) {
		if (!EnableSeedOrders) {
			return;
		}

		string orderUuid = GetDeterministicOrderUuid(
			tradingAccount.GetNumber(), tradingAccount.GetBrokerServer(), order.GetSymbol(),
			order.GetMagicNumber(), order.GetOrderId(), order.GetPositionId()
		);
		string strategyUuid = registry.GetStrategyUuid(order.GetMagicNumber());
		string assetUuid = registry.GetAssetUuid(order.GetSymbol());

		JSON::Object *json = BuildOrderJson(order, orderUuid, accountUuid, strategyUuid, assetUuid);
		ordersCollection.InsertOne(json);
		delete json;
	}
};

#endif
