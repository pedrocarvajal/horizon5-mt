#ifndef __SR_PERSISTENCE_OF_ORDERS_MQH__
#define __SR_PERSISTENCE_OF_ORDERS_MQH__

#include "../../helpers/HIsLiveTrading.mqh"

#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../SEDb/SEDb.mqh"

#include "../../entities/EOrder.mqh"

extern SEDateTime dtime;

class SRPersistenceOfOrders {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *ordersCollection;

public:
	SRPersistenceOfOrders() {
		logger.SetPrefix("OrderPersistence");
		ordersCollection = NULL;
	}

	void Initialize(string symbolName, string strategyName) {
		string basePath = StringFormat("Live/%s/%s", symbolName, strategyName);
		database.Initialize(basePath, true);
		ordersCollection = database.Collection("orders");
	}

	int LoadOrders(EOrder &restoredOrders[]) {
		if (!IsLiveTrading()) {
			return 0;
		}

		if (ordersCollection == NULL) {
			return 0;
		}

		int documentCount = ordersCollection.Count();
		logger.Debug(StringFormat("Starting order restoration, found %d documents", documentCount));

		if (documentCount == 0) {
			return 0;
		}

		SEDbQuery findAll;
		JSON::Object *documents[];
		int foundCount = ordersCollection.Find(findAll, documents);

		string idsToDelete[];
		int loadedCount = 0;

		for (int i = 0; i < foundCount; i++) {
			int result = loadAndValidateOrder(documents[i], restoredOrders, idsToDelete, i);

			if (result == -1) {
				return -1;
			}

			if (result == 1) {
				loadedCount++;
			}
		}

		cleanupOrphanedOrders(idsToDelete);

		logger.Debug("Order restoration completed");
		logger.Debug(StringFormat("Documents found: %d", foundCount));
		logger.Debug(StringFormat("Orders loaded: %d", loadedCount));
		return loadedCount;
	}

	bool SaveOrder(EOrder &order) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (ordersCollection == NULL) {
			return false;
		}

		JSON::Object *json = serializeOrder(order);
		JSON::Object *existing = ordersCollection.FindOne("_id", order.GetId());
		bool result;

		if (existing != NULL) {
			result = ordersCollection.UpdateOne("_id", order.GetId(), json);
		} else {
			result = ordersCollection.InsertOne(json);
		}

		delete json;

		if (result) {
			logger.Debug(StringFormat("Order saved to database: %s", order.GetId()));
		}

		return result;
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
			logger.Debug(StringFormat("Order deleted from database: %s", orderId));
		}

		return result;
	}

	int QueryOrders(SEDbQuery &query, JSON::Object *&results[]) {
		if (ordersCollection == NULL) {
			ArrayResize(results, 0);
			return 0;
		}

		return ordersCollection.Find(query, results);
	}

private:
	bool isExpiredOrder(EOrder &order) {
		if (order.GetStatus() != ORDER_STATUS_CLOSED && order.GetStatus() != ORDER_STATUS_CANCELLED) {
			return false;
		}

		datetime closeTimestamp = order.GetCloseAt().timestamp;

		if (closeTimestamp == 0) {
			return false;
		}

		return (TimeCurrent() - closeTimestamp) > 3600;
	}

	int loadAndValidateOrder(JSON::Object *document, EOrder &restoredOrders[], string &idsToDelete[], int index) {
		EOrder order;

		if (!deserializeOrder(document, order)) {
			logger.Error(StringFormat(
				"CRITICAL ERROR: Failed to deserialize order document at index %d",
				index
			));
			return -1;
		}

		if (isExpiredOrder(order)) {
			int deleteSize = ArraySize(idsToDelete);
			ArrayResize(idsToDelete, deleteSize + 1);
			idsToDelete[deleteSize] = order.GetId();
			return 0;
		}

		if (!validateOrderExists(order)) {
			if (reconcileClosedOrder(order)) {
				logger.Info(StringFormat(
					"Order reconciled from MT5 history: %s (closed while EA was offline)",
					order.GetId()
				));

				ArrayResize(restoredOrders, ArraySize(restoredOrders) + 1);
				restoredOrders[ArraySize(restoredOrders) - 1] = order;
				return 1;
			}

			logger.Warning(StringFormat(
				"Order no longer exists in MetaTrader and not found in history, cleaning up: %s",
				order.GetId()
			));

			int deleteSize = ArraySize(idsToDelete);
			ArrayResize(idsToDelete, deleteSize + 1);
			idsToDelete[deleteSize] = order.GetId();
			return 0;
		}

		ArrayResize(restoredOrders, ArraySize(restoredOrders) + 1);
		restoredOrders[ArraySize(restoredOrders) - 1] = order;

		logger.Info(StringFormat(
			"Order loaded successfully: %s (Status: %s)",
			order.GetId(),
			EnumToString(order.GetStatus())
		));

		return 1;
	}

	void cleanupOrphanedOrders(string &idsToDelete[]) {
		for (int i = 0; i < ArraySize(idsToDelete); i++) {
			ordersCollection.DeleteOne("_id", idsToDelete[i]);
		}
	}

	bool deserializeOrder(JSON::Object *json, EOrder &order) {
		if (json == NULL || !json.hasValue("_id")) {
			logger.Error("Failed to deserialize order document");
			return false;
		}

		order.SetIsInitialized(json.getBoolean("is_initialized"));
		order.SetIsProcessed(json.getBoolean("is_processed"));
		order.SetIsMarketOrder(json.getBoolean("is_market_order"));
		order.SetPendingToOpen(json.getBoolean("pending_to_open"));
		order.SetPendingToClose(json.getBoolean("pending_to_close"));
		order.SetRetryCount((int)json.getNumber("retry_count"));
		order.SetRetryAfter((datetime)json.getNumber("retry_after"));
		order.SetStatus((ENUM_ORDER_STATUSES)json.getNumber("status"));

		order.SetId(json.getString("_id"));
		order.SetSource(json.getString("source"));
		order.SetSymbol(json.getString("symbol"));
		order.SetMagicNumber((ulong)json.getNumber("magic_number"));
		order.SetSide((int)json.getNumber("side"));
		order.SetOrderId((ulong)json.getNumber("order_id"));
		order.SetDealId((ulong)json.getNumber("deal_id"));
		order.SetPositionId((ulong)json.getNumber("position_id"));

		order.SetVolume(json.getNumber("volume"));
		order.SetSignalPrice(json.getNumber("signal_price"));
		order.SetOpenAtPrice(json.getNumber("open_at_price"));
		order.SetOpenPrice(json.getNumber("open_price"));
		order.SetTakeProfitPrice(json.getNumber("take_profit_price"));
		order.SetStopLossPrice(json.getNumber("stop_loss_price"));

		order.SetClosePrice(json.getNumber("close_price"));
		order.SetProfitInDollars(json.getNumber("profit_in_dollars"));
		order.SetCloseReason((ENUM_DEAL_REASON)(int)json.getNumber("order_close_reason"));

		SDateTime signalAt = dtime.FromTimestamp((datetime)json.getNumber("signal_at"));
		SDateTime openAt = dtime.FromTimestamp((datetime)json.getNumber("open_at"));
		SDateTime closeAt = dtime.FromTimestamp((datetime)json.getNumber("close_at"));
		order.SetSignalAt(signalAt);
		order.SetOpenAt(openAt);
		order.SetCloseAt(closeAt);

		return true;
	}

	JSON::Object *serializeOrder(EOrder &order) {
		JSON::Object *json = new JSON::Object();

		json.setProperty("_id", order.GetId());
		json.setProperty("is_initialized", order.IsInitialized());
		json.setProperty("is_processed", order.IsProcessed());
		json.setProperty("is_market_order", order.IsMarketOrder());
		json.setProperty("pending_to_open", order.IsPendingToOpen());
		json.setProperty("pending_to_close", order.IsPendingToClose());
		json.setProperty("retry_count", order.GetRetryCount());
		json.setProperty("retry_after", (long)order.GetRetryAfter());
		json.setProperty("status", (int)order.GetStatus());

		json.setProperty("source", order.GetSource());
		json.setProperty("symbol", order.GetSymbol());
		json.setProperty("magic_number", (long)order.GetMagicNumber());
		json.setProperty("side", order.GetSide());
		json.setProperty("order_id", (long)order.GetOrderId());
		json.setProperty("deal_id", (long)order.GetDealId());
		json.setProperty("position_id", (long)order.GetPositionId());

		json.setProperty("volume", order.GetVolume());
		json.setProperty("signal_price", order.GetSignalPrice());
		json.setProperty("open_at_price", order.GetOpenAtPrice());
		json.setProperty("open_price", order.GetOpenPrice());
		json.setProperty("take_profit_price", order.GetTakeProfitPrice());
		json.setProperty("stop_loss_price", order.GetStopLossPrice());

		json.setProperty("close_price", order.GetClosePrice());
		json.setProperty("profit_in_dollars", order.GetProfitInDollars());
		json.setProperty("order_close_reason", (int)order.GetCloseReason());

		json.setProperty("signal_at", (long)order.GetSignalAt().timestamp);
		json.setProperty("open_at", (long)order.GetOpenAt().timestamp);
		json.setProperty("close_at", (long)order.GetCloseAt().timestamp);
		json.setProperty("saved_at", (long)dtime.Timestamp());

		return json;
	}

	bool reconcileClosedOrder(EOrder &order) {
		if (order.GetStatus() != ORDER_STATUS_OPEN || order.GetPositionId() == 0) {
			return false;
		}

		if (!HistorySelect(0, TimeCurrent())) {
			logger.Error("Failed to load deal history for order reconciliation");
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

			ordersCollection.UpdateOne("_id", order.GetId(), serializeOrder(order));

			return true;
		}

		return false;
	}

	bool validateOrderExists(EOrder &order) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (order.GetStatus() == ORDER_STATUS_CLOSED || order.GetStatus() == ORDER_STATUS_CANCELLED) {
			return true;
		}

		if (order.GetStatus() == ORDER_STATUS_PENDING && order.GetOrderId() > 0) {
			return OrderSelect(order.GetOrderId());
		}

		if (order.GetStatus() == ORDER_STATUS_OPEN && order.GetPositionId() > 0) {
			return PositionSelectByTicket(order.GetPositionId());
		}

		return false;
	}
};

#endif
