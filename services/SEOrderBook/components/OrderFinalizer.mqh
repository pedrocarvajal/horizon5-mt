#ifndef __ORDER_FINALIZER_MQH__
#define __ORDER_FINALIZER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../interfaces/IStrategy.mqh"

#include "../../SEDateTime/SEDateTime.mqh"
#include "../../SEDateTime/structs/SDateTime.mqh"

#include "../../SRPersistenceOfOrders/SRPersistenceOfOrders.mqh"

extern SEDateTime dtime;

class OrderFinalizer {
private:
	SRPersistenceOfOrders * persistence;
	IStrategy *listener;

public:
	OrderFinalizer() {
		persistence = NULL;
		listener = NULL;
	}

	void SetPersistence(SRPersistenceOfOrders *persistenceRef) {
		persistence = persistenceRef;
	}

	void SetListener(IStrategy *listenerRef) {
		listener = listenerRef;
	}

	void Persist(EOrder &order) {
		if (CheckPointer(persistence) == POINTER_INVALID) {
			return;
		}

		persistence.SaveOrder(GetPointer(order));
	}

	void FinalizeCancelled(EOrder &order) {
		order.SetStatus(ORDER_STATUS_CANCELLED);
		order.SetPendingToOpen(false);
		order.SetPendingToClose(false);
		order.SetIsProcessed(true);
		SDateTime cancelTime = dtime.Now();
		order.SetCloseAt(cancelTime);
		order.BuildSnapshot();

		Persist(order);

		if (CheckPointer(listener) != POINTER_INVALID) {
			listener.OnCancelOrder(order);
		}
	}
};

#endif
