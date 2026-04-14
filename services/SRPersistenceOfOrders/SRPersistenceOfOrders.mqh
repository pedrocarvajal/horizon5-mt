#ifndef __SR_PERSISTENCE_OF_ORDERS_MQH__
#define __SR_PERSISTENCE_OF_ORDERS_MQH__

#include "../../helpers/HIsLiveTrading.mqh"
#include "helpers/HSerializeOrder.mqh"

#include "../SELogger/SELogger.mqh"

#include "../SEDateTime/SEDateTime.mqh"

#include "../SEDb/SEDb.mqh"

#include "../../entities/EOrder.mqh"

#include "validators/OrderExistenceValidator.mqh"

#include "components/OrderReconciler.mqh"
#include "components/OrderLoader.mqh"

class SRPersistenceOfOrders {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *ordersCollection;

	OrderExistenceValidator existenceValidator;
	OrderReconciler reconciler;
	OrderLoader loader;

public:
	SRPersistenceOfOrders() {
		logger.SetPrefix("OrderPersistence");
		ordersCollection = NULL;
	}

	bool DeleteOrder(string orderId) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (ordersCollection == NULL) {
			return false;
		}

		bool result = ordersCollection.DeleteOne("_id", orderId);

		if (result) {
			ordersCollection.Flush();
			logger.Debug(LOG_CODE_PERSISTENCE_SAVE_FAILED, StringFormat("Order deleted from database: %s", orderId));
		}

		return result;
	}

	void Initialize(string symbolName, string strategyName) {
		string basePath = StringFormat("Live/%s/%s", symbolName, strategyName);
		database.Initialize(basePath, true);
		ordersCollection = database.Collection("orders");

		reconciler.Initialize(ordersCollection);
		loader.Initialize(ordersCollection, GetPointer(reconciler), GetPointer(existenceValidator));
	}

	int LoadOrders(EOrder &restoredOrders[]) {
		if (!IsLiveTrading()) {
			return 0;
		}

		if (ordersCollection == NULL) {
			return 0;
		}

		return loader.Load(restoredOrders);
	}

	int QueryOrders(SEDbQuery &query, JSON::Object *&results[]) {
		if (ordersCollection == NULL) {
			ArrayResize(results, 0);
			return 0;
		}

		return ordersCollection.Find(query, results);
	}

	bool SaveOrder(EOrder &order) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (ordersCollection == NULL) {
			return false;
		}

		JSON::Object *json = SerializeOrder(order);
		JSON::Object *existing = ordersCollection.FindOne("_id", order.GetId());
		bool result;

		if (existing != NULL) {
			delete existing;
			result = ordersCollection.UpdateOne("_id", order.GetId(), json);
		} else {
			result = ordersCollection.InsertOne(json);
		}

		delete json;

		if (result) {
			ordersCollection.Flush();
			logger.Debug(LOG_CODE_PERSISTENCE_SAVE_FAILED, StringFormat("Order saved to database: %s", order.GetId()));
		}

		return result;
	}
};

#endif
