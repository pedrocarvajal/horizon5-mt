#ifndef __ORDER_RECONCILER_MQH__
#define __ORDER_RECONCILER_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../SEDateTime/SEDateTime.mqh"
#include "../../SEDateTime/structs/SDateTime.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "../helpers/HSerializeOrder.mqh"

#include "../../../constants/COHorizon.mqh"

extern SEDateTime dtime;

class OrderReconciler {
private:
	SELogger logger;
	SEDbCollection *collection;

public:
	OrderReconciler() {
		logger.SetPrefix("OrderPersistence::Reconciler");
		collection = NULL;
	}

	void Initialize(SEDbCollection *ordersCollection) {
		collection = ordersCollection;
	}

	bool Reconcile(EOrder &order) {
		if (order.GetStatus() != ORDER_STATUS_OPEN || order.GetPositionId() == 0) {
			return false;
		}

		if (!HistorySelect(0, TimeCurrent())) {
			logger.Error(
				LOG_CODE_PERSISTENCE_LOAD_FAILED,
				"deal history load failed | reason='order reconciliation'"
			);
			return false;
		}

		ulong positionId = order.GetPositionId();
		int totalDeals = HistoryDealsTotal();

		for (int i = totalDeals - 1; i >= 0; i--) {
			ulong dealTicket = HistoryDealGetTicket(i);

			if (dealTicket == 0) {
				continue;
			}

			if (HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) != (long)positionId) {
				continue;
			}

			if ((int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) {
				continue;
			}

			double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
			double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
			double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
			double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
			double netProfit = dealProfit + (dealCommission * COMMISSION_ROUND_TRIP_MULTIPLIER) + dealSwap;
			ENUM_DEAL_REASON dealReason =
				(ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
			datetime dealTimestamp = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
			SDateTime dealTime = dtime.FromTimestamp(dealTimestamp);

			order.SetCloseAt(dealTime);
			order.SetClosePrice(dealPrice);
			order.SetProfitInDollars(netProfit);
			order.SetGrossProfit(dealProfit);
			order.SetCommission(dealCommission);
			order.SetSwap(dealSwap);
			order.SetCloseReason(dealReason);
			order.SetStatus(ORDER_STATUS_CLOSED);

			JSON::Object *json = SerializeOrder(order);
			collection.UpdateOne("_id", order.GetId(), json);
			delete json;

			return true;
		}

		return false;
	}
};

#endif
