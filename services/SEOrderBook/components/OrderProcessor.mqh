#ifndef __ORDER_PROCESSOR_MQH__
#define __ORDER_PROCESSOR_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../entities/ETradingStatus.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../SELogger/SELogger.mqh"

#include "OrderCanceller.mqh"

#include "OrderCloser.mqh"

#include "OrderOpener.mqh"

class OrderProcessor {
private:
	SELogger logger;
	OrderOpener *opener;
	OrderCloser *closer;
	OrderCanceller *canceller;
	ETradingStatus *tradingStatus;

public:
	OrderProcessor() {
		logger.SetPrefix("OrderBook::Processor");
		opener = NULL;
		closer = NULL;
		canceller = NULL;
		tradingStatus = NULL;
	}

	void Initialize(
		OrderOpener *openerRef,
		OrderCloser *closerRef,
		OrderCanceller *cancellerRef
	) {
		opener = openerRef;
		closer = closerRef;
		canceller = cancellerRef;
	}

	void Process(EOrder &orders[]) {
		for (int i = 0; i < ArraySize(orders); i++) {
			if (!orders[i].IsInitialized()) {
				orders[i].OnInit();
			}

			ENUM_ORDER_STATUSES currentStatus = orders[i].GetStatus();

			if (currentStatus == ORDER_STATUS_PENDING) {
				if (orders[i].IsPendingToClose()) {
					canceller.CheckToCancel(orders[i]);
				} else if (isTradingPaused()) {
					canceller.CheckToCancel(orders[i]);
				} else {
					opener.CheckToOpen(orders[i]);
				}
			} else if (currentStatus == ORDER_STATUS_OPEN) {
				closer.CheckToClose(orders[i]);
			}
		}
	}

	void SetTradingStatus(ETradingStatus *tradingStatusRef) {
		tradingStatus = tradingStatusRef;
	}

private:
	bool isTradingPaused() {
		return CheckPointer(tradingStatus) != POINTER_INVALID && tradingStatus.IsPaused();
	}
};

#endif
