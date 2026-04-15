#ifndef __ORDER_LOADER_MQH__
#define __ORDER_LOADER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../SEDateTime/SEDateTime.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "../helpers/HDeserializeOrder.mqh"
#include "../helpers/HIsExpiredOrder.mqh"

#include "../validators/OrderExistenceValidator.mqh"

#include "OrderReconciler.mqh"

extern SEDateTime dtime;

class OrderLoader {
private:
	SELogger logger;
	SEDbCollection *collection;
	OrderReconciler *reconciler;
	OrderExistenceValidator *validator;

public:
	OrderLoader() {
		logger.SetPrefix("OrderPersistence::Loader");
		collection = NULL;
		reconciler = NULL;
		validator = NULL;
	}

	void Initialize(
		SEDbCollection *ordersCollection,
		OrderReconciler *orderReconciler,
		OrderExistenceValidator *existenceValidator
	) {
		collection = ordersCollection;
		reconciler = orderReconciler;
		validator = existenceValidator;
	}

	int Load(EOrder &restoredOrders[]) {
		int documentCount = collection.Count();
		logger.Debug(
			LOG_CODE_PERSISTENCE_SAVE_FAILED,
			StringFormat(
				"Starting order restoration, found %d documents",
				documentCount
		));

		if (documentCount == 0) {
			return 0;
		}

		SEDbQuery findAll;
		JSON::Object *documents[];
		int foundCount = collection.Find(findAll, documents);

		string idsToDelete[];
		int loadedCount = 0;

		for (int i = 0; i < foundCount; i++) {
			int result = loadAndValidateOrder(documents[i], restoredOrders, idsToDelete, i);
			delete documents[i];

			if (result == -1) {
				for (int j = i + 1; j < foundCount; j++) {
					delete documents[j];
				}
				return -1;
			}

			if (result == 1) {
				loadedCount++;
			}
		}

		cleanupOrphanedOrders(idsToDelete);

		logger.Debug(
			LOG_CODE_PERSISTENCE_SAVE_FAILED,
			"Order restoration completed"
		);
		logger.Debug(
			LOG_CODE_PERSISTENCE_SAVE_FAILED,
			StringFormat(
				"Documents found: %d",
				foundCount
		));
		logger.Debug(
			LOG_CODE_PERSISTENCE_SAVE_FAILED,
			StringFormat(
				"Orders loaded: %d",
				loadedCount
		));
		return loadedCount;
	}

private:
	void appendOrder(EOrder &restoredOrders[], EOrder &order) {
		ArrayResize(restoredOrders, ArraySize(restoredOrders) + 1);
		restoredOrders[ArraySize(restoredOrders) - 1] = order;
	}

	void cleanupOrphanedOrders(string &idsToDelete[]) {
		for (int i = 0; i < ArraySize(idsToDelete); i++) {
			collection.DeleteOne("_id", idsToDelete[i]);
		}

		if (ArraySize(idsToDelete) > 0) {
			collection.Flush();
		}
	}

	int loadAndValidateOrder(JSON::Object *document, EOrder &restoredOrders[], string &idsToDelete[], int index) {
		EOrder order;

		if (!DeserializeOrder(document, order)) {
			logger.Error(
				LOG_CODE_PERSISTENCE_LOAD_FAILED,
				StringFormat(
					"CRITICAL ERROR: Failed to deserialize order document at index %d",
					index
			));
			return -1;
		}

		if (IsExpiredOrder(order)) {
			int deleteSize = ArraySize(idsToDelete);
			ArrayResize(idsToDelete, deleteSize + 1);
			idsToDelete[deleteSize] = order.GetId();
			return 0;
		}

		if (!validator.Validate(order)) {
			if (reconciler.Reconcile(order)) {
				logger.Info(
					LOG_CODE_PERSISTENCE_SAVE_FAILED,
					StringFormat(
						"Order reconciled from MT5 history: %s (closed while EA was offline)",
						order.GetId()
				));

				appendOrder(restoredOrders, order);
				return 1;
			}

			logger.Warning(
				LOG_CODE_PERSISTENCE_LOAD_FAILED,
				StringFormat(
					"Order no longer exists in MetaTrader and not found in history, marking as cancelled: %s",
					order.GetId()
			));

			order.SetStatus(ORDER_STATUS_CANCELLED);
			order.SetIsProcessed(true);
			SDateTime cancelTime = dtime.Now();
			order.SetCloseAt(cancelTime);

			appendOrder(restoredOrders, order);
			return 1;
		}

		appendOrder(restoredOrders, order);

		logger.Info(
			LOG_CODE_PERSISTENCE_SAVE_FAILED,
			StringFormat(
				"Order loaded successfully: %s (Status: %s)",
				order.GetId(),
				EnumToString(order.GetStatus())
		));

		return 1;
	}
};

#endif
