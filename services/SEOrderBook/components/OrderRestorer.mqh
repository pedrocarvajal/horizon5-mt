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

	int LoadActiveOrders(
		EOrder &existingOrders[],
		EOrder &activeOrders[]
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

		ArrayResize(activeOrders, loadedCount);

		int activeCount = 0;

		for (int i = 0; i < loadedCount; i++) {
			ENUM_ORDER_STATUSES orderStatus = loadedOrders[i].GetStatus();

			if (orderStatus == ORDER_STATUS_CLOSED || orderStatus == ORDER_STATUS_CANCELLED) {
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
