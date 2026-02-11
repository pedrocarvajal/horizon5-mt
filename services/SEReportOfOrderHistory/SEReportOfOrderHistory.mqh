#ifndef __SE_REPORT_OF_ORDER_HISTORY_MQH__
#define __SE_REPORT_OF_ORDER_HISTORY_MQH__

#include "../../structs/SSOrderHistory.mqh"
#include "../../helpers/HGetReportsPath.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"

class SEReportOfOrderHistory {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *ordersCollection;

	string reportsDir;
	string reportName;

	void initialize(string directory, string name) {
		logger.SetPrefix("OrderHistoryReporter");
		reportsDir = directory;
		reportName = name;

		database.Initialize(directory, true);
		ordersCollection = database.Collection(name);
		ordersCollection.SetAutoFlush(false);
	}

	JSON::Object *orderHistoryToJson(const SSOrderHistory &history) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("order_id", history.orderId);
		obj.setProperty("symbol", history.symbol);
		obj.setProperty("strategy_name", history.strategyName);
		obj.setProperty("strategy_prefix", history.strategyPrefix);
		obj.setProperty("magic_number", (long)history.magicNumber);
		obj.setProperty("deal_id", (long)history.dealId);
		obj.setProperty("position_id", (long)history.positionId);
		obj.setProperty("status", (int)history.status);
		obj.setProperty("side", history.side);
		obj.setProperty("order_close_reason", (int)history.orderCloseReason);
		obj.setProperty("main_take_profit_at_price", history.takeProfitPrice);
		obj.setProperty("main_stop_loss_at_price", history.stopLossPrice);
		obj.setProperty("signal_at", (long)history.signalAt);
		obj.setProperty("signal_price", history.signalPrice);
		obj.setProperty("open_time", (long)history.openTime);
		obj.setProperty("open_price", history.openPrice);
		obj.setProperty("open_lot", history.openLot);
		obj.setProperty("close_time", (long)history.closeTime);
		obj.setProperty("close_price", history.closePrice);
		obj.setProperty("profit_in_dollars", history.profitInDollars);

		return obj;
	}

public:
	SEReportOfOrderHistory(string symbol, string customReportName) {
		initialize(GetReportsPath(symbol), customReportName);
	}

	void AddOrderSnapshot(const SSOrderHistory &snapshot) {
		JSON::Object *json = orderHistoryToJson(snapshot);
		ordersCollection.InsertOne(json);
		delete json;
	}

	void Export() {
		logger.debug(StringFormat(
			"Exporting %d orders to %s\\%s.json",
			ordersCollection.Count(), GetCurrentReportsPath(), reportName
		));

		ordersCollection.Flush();

		logger.info(StringFormat(
			"Order history saved - %s.json with %d orders",
			reportName,
			ordersCollection.Count()
		));
	}

	int GetOrderCount() {
		return ordersCollection.Count();
	}

	string GetCurrentReportsPath() {
		string pathSeparator = "\\";
		string convertedDir = reportsDir;
		StringReplace(convertedDir, "/", pathSeparator);

		return StringFormat("%s%sFiles%s",
			TerminalInfoString(TERMINAL_COMMONDATA_PATH),
			pathSeparator,
			convertedDir
		);
	}
};

#endif
