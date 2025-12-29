#ifndef __SE_REPORT_OF_ORDER_HISTORY_MQH__
#define __SE_REPORT_OF_ORDER_HISTORY_MQH__

#include "../../libraries/json/index.mqh"
#include "../../structs/SSOrderHistory.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"

extern SEDateTime dtime;

class SEReportOfOrderHistory {
private:
	SELogger logger;

	string reportsDir;
	bool useCommonFiles;
	SSOrderHistory orderHistory[];

	JSON::Object *OrderHistoryToJson(const SSOrderHistory &history) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("order_id", history.orderId);
		obj.setProperty("strategy_name", history.strategyName);
		obj.setProperty("strategy_prefix", history.strategyPrefix);
		obj.setProperty("magic_number", (long)history.magicNumber);
		obj.setProperty("status", (int)history.status);
		obj.setProperty("side", history.side);
		obj.setProperty("order_close_reason", (int)history.orderCloseReason);
		obj.setProperty("main_take_profit_at_price", history.mainTakeProfitAtPrice);
		obj.setProperty("main_stop_loss_at_price", history.mainStopLossAtPrice);
		obj.setProperty("signal_at", (long)history.signalAt);
		obj.setProperty("open_time", (long)history.openTime);
		obj.setProperty("open_price", history.openPrice);
		obj.setProperty("open_lot", history.openLot);
		obj.setProperty("close_time", (long)history.closeTime);
		obj.setProperty("close_price", history.closePrice);
		obj.setProperty("profit_in_dollars", history.profitInDollars);

		return obj;
	}

	JSON::Array *OrderHistoryArrayToJsonArray(const SSOrderHistory &histories[], int count) {
		JSON::Array *arr = new JSON::Array();
		for (int i = 0; i < count; i++)
			arr.add(OrderHistoryToJson(histories[i]));
		return arr;
	}

public:
	SEReportOfOrderHistory() {
		logger.SetPrefix("OrderHistoryReporter");

		MqlDateTime dt = dtime.Now();
		string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
		reportsDir = "/Reports/" + _Symbol + "/" + timestamp;
		useCommonFiles = false;
		ArrayResize(orderHistory, 0);
	}

	SEReportOfOrderHistory(string customDir, bool useCommonFolder = false) {
		logger.SetPrefix("OrderHistoryReporter");

		reportsDir = customDir;
		useCommonFiles = useCommonFolder;
		ArrayResize(orderHistory, 0);
	}

	void AddOrderSnapshot(const SSOrderHistory &snapshot) {
		ArrayResize(orderHistory, ArraySize(orderHistory) + 1);
		orderHistory[ArraySize(orderHistory) - 1] = snapshot;
	}

	void ExportOrderHistoryToJsonFile() {
		JSON::Object *root = new JSON::Object();
		root.setProperty("name", "Orders Report");

		if (ArraySize(orderHistory) == 0) {
			logger.warning("No order history data to export - creating empty report");
			JSON::Array *emptyArray = new JSON::Array();
			root.setProperty("data", emptyArray);
		} else {
			root.setProperty("data", OrderHistoryArrayToJsonArray(orderHistory, ArraySize(orderHistory)));
		}

		string jsonStr = root.toString();
		string filename = reportsDir + "/OrdersReport.json";

		int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;
		if (useCommonFiles)
			flags |= FILE_COMMON;

		logger.debug("Attempting to create order history file: " + filename);
		logger.debug("Full path: " + GetCurrentReportsPath() + "\\OrdersReport.json");
		logger.debug("Orders to export: " + IntegerToString(ArraySize(orderHistory)));

		int file = FileOpen(filename, flags);

		if (file == INVALID_HANDLE) {
			int errorCode = GetLastError();
			logger.error("Cannot create order history file '" + filename + "' - Error code: " + IntegerToString(errorCode));
			logger.error("Flags used: " + IntegerToString(flags) + " (FILE_WRITE=" + IntegerToString(FILE_WRITE) + ", FILE_TXT=" + IntegerToString(FILE_TXT) + ", FILE_ANSI=" + IntegerToString(FILE_ANSI) + ", FILE_COMMON=" + IntegerToString(FILE_COMMON) + ")");
		} else {
			FileWriteString(file, jsonStr);
			FileClose(file);
			logger.info("Order history saved - OrdersReport.json with " + IntegerToString(ArraySize(orderHistory)) + " orders");
		}

		delete root;
	}

	void PrintCurrentPath() {
		logger.info("Order history reports saved to: " + GetCurrentReportsPath());
	}

	int GetOrderCount() {
		return ArraySize(orderHistory);
	}

	string GetCurrentReportsPath() {
		string pathSeparator = "\\";
		string convertedDir = reportsDir;
		StringReplace(convertedDir, "/", pathSeparator);

		if (useCommonFiles)
			return TerminalInfoString(TERMINAL_COMMONDATA_PATH) + pathSeparator + "Files" + convertedDir;
		else
			return TerminalInfoString(TERMINAL_DATA_PATH) + pathSeparator + "MQL5" + pathSeparator + "Files" + convertedDir;
	}
};

#endif
