#ifndef __ORDER_RESTORER_MQH__
#define __ORDER_RESTORER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"

class OrderRestorer {
private:
	SELogger logger;
	string prefix;
	SRPersistenceOfOrders *persistence;

public:
	OrderRestorer() {
		logger.SetPrefix("OrderBook::Restorer");
		persistence = NULL;
	}

	void Initialize(string orderPrefix) {
		prefix = orderPrefix;
	}

	void SetPersistence(SRPersistenceOfOrders *persistenceRef) {
		persistence = persistenceRef;
	}

	int QueryOrders(SEDbQuery &query, JSON::Object *&results[]) {
		if (CheckPointer(persistence) == POINTER_INVALID) {
			ArrayResize(results, 0);
			return 0;
		}

		return persistence.QueryOrders(query, results);
	}

	int LoadAndSplit(
		EOrder &existingOrders[],
		EOrder &activeOrders[],
		EOrder &reconciledOrders[]
	) {
		ArrayResize(activeOrders, 0);

		if (CheckPointer(persistence) == POINTER_INVALID) {
			return 0;
		}

		EOrder loadedOrders[];
		int loadedCount = persistence.LoadOrders(loadedOrders);

		if (loadedCount == -1) {
			logger.Error(
				LOG_CODE_PERSISTENCE_LOAD_FAILED,
				StringFormat(
					"orders restore failed | strategy=%s reason='persistence load error'",
					prefix
			));
			return -1;
		}

		int reconciledOffset = ArraySize(reconciledOrders);
		ArrayResize(activeOrders, loadedCount);
		ArrayResize(reconciledOrders, reconciledOffset + loadedCount);

		int activeCount = 0;
		int reconciledCount = 0;

		for (int i = 0; i < loadedCount; i++) {
			ENUM_ORDER_STATUSES orderStatus = loadedOrders[i].GetStatus();

			if (orderStatus == ORDER_STATUS_CLOSED || orderStatus == ORDER_STATUS_CANCELLED) {
				reconciledOrders[reconciledOffset + reconciledCount] = loadedOrders[i];
				reconciledCount++;
				continue;
			}

			if (isDuplicate(loadedOrders[i].GetId(), existingOrders)) {
				continue;
			}

			loadedOrders[i].OnInit();
			activeOrders[activeCount] = loadedOrders[i];
			activeCount++;
		}

		ArrayResize(activeOrders, activeCount);
		ArrayResize(reconciledOrders, reconciledOffset + reconciledCount);

		if (activeCount > 0) {
			logger.Info(
				LOG_CODE_ORDER_RESTORED,
				StringFormat(
					"orders restored | strategy=%s count=%d",
					prefix,
					activeCount
			));
		}

		return activeCount;
	}

private:
	bool isDuplicate(string id, EOrder &existing[]) {
		for (int i = 0; i < ArraySize(existing); i++) {
			if (existing[i].GetId() == id) {
				return true;
			}
		}
		return false;
	}
};

#endif
