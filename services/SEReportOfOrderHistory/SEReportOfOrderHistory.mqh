#ifndef __SE_REPORT_OF_ORDER_HISTORY_MQH__
#define __SE_REPORT_OF_ORDER_HISTORY_MQH__

#include "../../libraries/json/index.mqh"
#include "../../structs/SSOrderHistory.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../SEDateTime/structs/SDateTime.mqh"


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

	JSON::Array *OrderHistoryArrayToJsonArray(
		const SSOrderHistory &histories[],
		int count
	) {
		JSON::Array *arr = new JSON::Array();

		for (int i = 0; i < count; i++)
			arr.add(OrderHistoryToJson(histories[i]));

		return arr;
	}

public:
	SEReportOfOrderHistory() {
		logger.SetPrefix("OrderHistoryReporter");

		reportsDir = StringFormat("/Reports/%s/%s", _Symbol, TimeToString(dtime.Timestamp(), TIME_DATE));
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
		string filename = StringFormat("%s/OrdersReport.json", reportsDir);
		int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;

		if (useCommonFiles)
			flags |= FILE_COMMON;

		logger.debug(StringFormat("Attempting to create order history file: %s", filename));
		logger.debug(StringFormat("Full path: %s\\OrdersReport.json", GetCurrentReportsPath()));
		logger.debug(StringFormat("Orders to export: %d", ArraySize(orderHistory)));

		int file = FileOpen(filename, flags);

		if (file == INVALID_HANDLE) {
			int errorCode = GetLastError();

			logger.error(StringFormat(
				"Cannot create order history file '%s' - Error code: %d",
				filename,
				errorCode
			));

			logger.error(StringFormat(
				"Flags used: %d (FILE_WRITE=%d, FILE_TXT=%d, FILE_ANSI=%d, FILE_COMMON=%d)",
				flags,
				FILE_WRITE,
				FILE_TXT,
				FILE_ANSI,
				FILE_COMMON
			));
		} else {
			FileWriteString(file, jsonStr);
			FileClose(file);

			logger.info(StringFormat(
				"Order history saved - OrdersReport.json with %d orders",
				ArraySize(orderHistory)
			));
		}

		delete root;
	}

	void PrintCurrentPath() {
		logger.info(StringFormat("Order history reports saved to: %s", GetCurrentReportsPath()));
	}

	int GetOrderCount() {
		return ArraySize(orderHistory);
	}

	string GetCurrentReportsPath() {
		string pathSeparator = "\\";
		string convertedDir = reportsDir;
		StringReplace(convertedDir, "/", pathSeparator);

		if (useCommonFiles) {
			return StringFormat("%s%sFiles%s",
				TerminalInfoString(TERMINAL_COMMONDATA_PATH),
				pathSeparator,
				convertedDir
			);
		} else {
			return StringFormat("%s%sMQL5%sFiles%s",
				TerminalInfoString(TERMINAL_DATA_PATH),
				pathSeparator,
				pathSeparator,
				convertedDir
			);
		}
	}
};

#endif
