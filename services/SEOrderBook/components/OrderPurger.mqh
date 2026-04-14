#ifndef __ORDER_PURGER_MQH__
#define __ORDER_PURGER_MQH__

#include "../../../constants/COTime.mqh"

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../SEDateTime/SEDateTime.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"

extern SEDateTime dtime;

class OrderPurger {
private:
	SELogger logger;
	SRPersistenceOfOrders *persistence;

public:
	OrderPurger() {
		logger.SetPrefix("OrderBook::Purger");
		persistence = NULL;
	}

	void SetPersistence(SRPersistenceOfOrders *persistenceRef) {
		persistence = persistenceRef;
	}

	void Purge(EOrder &orders[]) {
		datetime threshold = dtime.Timestamp() - SECONDS_IN_24_HOURS;
		int writeIndex = 0;
		string idsToPurge[];

		for (int i = 0; i < ArraySize(orders); i++) {
			ENUM_ORDER_STATUSES orderStatus = orders[i].GetStatus();
			datetime closedAt = orders[i].GetCloseAt().timestamp;
			bool isDead = (orderStatus == ORDER_STATUS_CLOSED || orderStatus == ORDER_STATUS_CANCELLED);
			bool isOldEnough = (closedAt > 0 && closedAt < threshold);

			if (isDead && isOldEnough) {
				int purgeSize = ArraySize(idsToPurge);
				ArrayResize(idsToPurge, purgeSize + 1);
				idsToPurge[purgeSize] = orders[i].GetId();
				continue;
			}

			if (writeIndex != i) {
				orders[writeIndex] = orders[i];
			}

			writeIndex++;
		}

		int purged = ArraySize(idsToPurge);

		if (purged > 0) {
			ArrayResize(orders, writeIndex);

			if (CheckPointer(persistence) != POINTER_INVALID) {
				for (int i = 0; i < purged; i++) {
					persistence.DeleteOrder(idsToPurge[i]);
				}
			}

			logger.Info(LOG_CODE_ORDER_PURGED, StringFormat(
				"orders purged | count=%d",
				purged
			));
		}
	}
};

#endif
