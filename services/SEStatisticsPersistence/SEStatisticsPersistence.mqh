#ifndef __SE_STATISTICS_PERSISTENCE_MQH__
#define __SE_STATISTICS_PERSISTENCE_MQH__

#include "../../helpers/HIsLiveTrading.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"
#include "../SEStatistics/SEStatistics.mqh"

class SEStatisticsPersistence {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *statisticsCollection;

	JSON::Array *serializeDoubleArray(double &arr[]) {
		JSON::Array *jsonArray = new JSON::Array();

		for (int i = 0; i < ArraySize(arr); i++) {
			jsonArray.add(arr[i]);
		}

		return jsonArray;
	}

	void deserializeDoubleArray(JSON::Array *jsonArray, double &arr[]) {
		if (jsonArray == NULL) {
			ArrayResize(arr, 0);
			return;
		}

		int length = jsonArray.getLength();
		ArrayResize(arr, length);

		for (int i = 0; i < length; i++) {
			arr[i] = jsonArray.getNumber(i);
		}
	}

	JSON::Array *serializeOrdersHistory(SSOrderHistory &orders[]) {
		JSON::Array *jsonArray = new JSON::Array();

		for (int i = 0; i < ArraySize(orders); i++) {
			JSON::Object *obj = new JSON::Object();
			obj.setProperty("order_id", orders[i].orderId);
			obj.setProperty("symbol", orders[i].symbol);
			obj.setProperty("strategy_name", orders[i].strategyName);
			obj.setProperty("strategy_prefix", orders[i].strategyPrefix);
			obj.setProperty("magic_number", (long)orders[i].magicNumber);
			obj.setProperty("deal_id", (long)orders[i].dealId);
			obj.setProperty("position_id", (long)orders[i].positionId);
			obj.setProperty("status", (int)orders[i].status);
			obj.setProperty("side", orders[i].side);
			obj.setProperty("order_close_reason", (int)orders[i].orderCloseReason);
			obj.setProperty("take_profit_price", orders[i].takeProfitPrice);
			obj.setProperty("stop_loss_price", orders[i].stopLossPrice);
			obj.setProperty("signal_at", (long)orders[i].signalAt);
			obj.setProperty("signal_price", orders[i].signalPrice);
			obj.setProperty("open_time", (long)orders[i].openTime);
			obj.setProperty("open_price", orders[i].openPrice);
			obj.setProperty("open_lot", orders[i].openLot);
			obj.setProperty("close_time", (long)orders[i].closeTime);
			obj.setProperty("close_price", orders[i].closePrice);
			obj.setProperty("profit_in_dollars", orders[i].profitInDollars);
			jsonArray.add(obj);
		}

		return jsonArray;
	}

	void deserializeOrdersHistory(JSON::Array *jsonArray, SSOrderHistory &orders[]) {
		if (jsonArray == NULL) {
			ArrayResize(orders, 0);
			return;
		}

		int length = jsonArray.getLength();
		ArrayResize(orders, length);

		for (int i = 0; i < length; i++) {
			JSON::Object *obj = jsonArray.getObject(i);

			if (obj == NULL) {
				continue;
			}

			orders[i].orderId = obj.getString("order_id");
			orders[i].symbol = obj.getString("symbol");
			orders[i].strategyName = obj.getString("strategy_name");
			orders[i].strategyPrefix = obj.getString("strategy_prefix");
			orders[i].magicNumber = (ulong)obj.getNumber("magic_number");
			orders[i].dealId = (ulong)obj.getNumber("deal_id");
			orders[i].positionId = (ulong)obj.getNumber("position_id");
			orders[i].status = (ENUM_ORDER_STATUSES)(int)obj.getNumber("status");
			orders[i].side = (int)obj.getNumber("side");
			orders[i].orderCloseReason = (ENUM_DEAL_REASON)(int)obj.getNumber("order_close_reason");
			orders[i].takeProfitPrice = obj.getNumber("take_profit_price");
			orders[i].stopLossPrice = obj.getNumber("stop_loss_price");
			orders[i].signalAt = (datetime)obj.getNumber("signal_at");
			orders[i].signalPrice = obj.getNumber("signal_price");
			orders[i].openTime = (datetime)obj.getNumber("open_time");
			orders[i].openPrice = obj.getNumber("open_price");
			orders[i].openLot = obj.getNumber("open_lot");
			orders[i].closeTime = (datetime)obj.getNumber("close_time");
			orders[i].closePrice = obj.getNumber("close_price");
			orders[i].profitInDollars = obj.getNumber("profit_in_dollars");
		}
	}

	JSON::Object *serialize(SEStatistics *stats) {
		JSON::Object *json = new JSON::Object();
		json.setProperty("_id", "state");
		json.setProperty("initial_balance", stats.GetInitialBalance());
		json.setProperty("start_time", (long)stats.GetStartTime());
		json.setProperty("nav_peak", stats.GetNavPeak());
		json.setProperty("nav_yesterday", stats.GetNavYesterday());
		json.setProperty("drawdown_max_dollars", stats.GetDrawdownMaxInDollars());
		json.setProperty("drawdown_max_percentage", stats.GetDrawdownMaxInPercentage());
		json.setProperty("winning_orders", stats.GetWinningOrders());
		json.setProperty("winning_orders_performance", stats.GetWinningOrdersPerformance());
		json.setProperty("losing_orders", stats.GetLosingOrders());
		json.setProperty("losing_orders_performance", stats.GetLosingOrdersPerformance());
		json.setProperty("max_loss", stats.GetMaxLoss());
		json.setProperty("max_exposure_lots", stats.GetMaxExposureInLots());
		json.setProperty("max_exposure_percentage", stats.GetMaxExposureInPercentage());
		json.setProperty("stop_out_detected", stats.GetStopOutDetected());

		double navArray[];
		stats.GetNavArray(navArray);
		json.setProperty("nav", serializeDoubleArray(navArray));

		double performanceArray[];
		stats.GetPerformanceArray(performanceArray);
		json.setProperty("performance", serializeDoubleArray(performanceArray));

		double returnsArray[];
		stats.GetReturnsArray(returnsArray);
		json.setProperty("returns", serializeDoubleArray(returnsArray));

		SSOrderHistory ordersHistory[];
		stats.GetOrdersHistory(ordersHistory);
		json.setProperty("orders_history", serializeOrdersHistory(ordersHistory));

		return json;
	}

	bool deserialize(JSON::Object *json, SEStatistics *stats) {
		if (json == NULL || !json.hasValue("_id")) {
			return false;
		}

		SStatisticsState state;
		state.startTime = (datetime)json.getNumber("start_time");
		state.navPeak = json.getNumber("nav_peak");
		state.navYesterday = json.getNumber("nav_yesterday");
		state.drawdownMaxInDollars = json.getNumber("drawdown_max_dollars");
		state.drawdownMaxInPercentage = json.getNumber("drawdown_max_percentage");
		state.winningOrders = (int)json.getNumber("winning_orders");
		state.winningOrdersPerformance = json.getNumber("winning_orders_performance");
		state.losingOrders = (int)json.getNumber("losing_orders");
		state.losingOrdersPerformance = json.getNumber("losing_orders_performance");
		state.maxLoss = json.getNumber("max_loss");
		state.maxExposureInLots = json.getNumber("max_exposure_lots");
		state.maxExposureInPercentage = json.getNumber("max_exposure_percentage");
		state.stopOutDetected = json.getBoolean("stop_out_detected");

		deserializeDoubleArray(json.getArray("nav"), state.nav);
		deserializeDoubleArray(json.getArray("performance"), state.performance);
		deserializeDoubleArray(json.getArray("returns"), state.returns);
		deserializeOrdersHistory(json.getArray("orders_history"), state.ordersHistory);

		stats.RestoreState(state);

		return true;
	}

public:
	SEStatisticsPersistence() {
		logger.SetPrefix("StatisticsPersistence");
		statisticsCollection = NULL;
	}

	void Initialize(string strategyPrefix) {
		string basePath = StringFormat("Live/%s/%s", _Symbol, strategyPrefix);
		database.Initialize(basePath, true);
		statisticsCollection = database.Collection("statistics");
	}

	bool Save(SEStatistics *stats) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (statisticsCollection == NULL) {
			return false;
		}

		JSON::Object *json = serialize(stats);
		JSON::Object *existing = statisticsCollection.FindOne("_id", "state");
		bool result;

		if (existing != NULL) {
			result = statisticsCollection.UpdateOne("_id", "state", json);
		} else {
			result = statisticsCollection.InsertOne(json);
		}

		delete json;

		if (result) {
			logger.Info("Statistics saved to database");
		}

		return result;
	}

	bool Load(SEStatistics *stats) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (statisticsCollection == NULL) {
			return false;
		}

		JSON::Object *document = statisticsCollection.FindOne("_id", "state");

		if (document == NULL) {
			logger.Info("No saved statistics found, starting fresh");
			return true;
		}

		bool result = deserialize(document, stats);

		if (result) {
			logger.Info("Statistics restored from database");
		} else {
			logger.Error("Failed to deserialize statistics");
		}

		return result;
	}
};

#endif
