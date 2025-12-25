#ifndef __REPORT_OF_ORDER_HISTORY_MQH__
#define __REPORT_OF_ORDER_HISTORY_MQH__

class ReportOfOrderHistory {
private:
	string reports_dir;
	bool use_common_files;
	SOrderHistory order_history[];
	Logger logger;

	JSON::Object *OrderHistoryToJson(const SOrderHistory &history) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("order_id", history.order_id);
		obj.setProperty("strategy_name", history.strategy_name);
		obj.setProperty("strategy_prefix", history.strategy_prefix);
		obj.setProperty("source_custom_id", history.source_custom_id);
		obj.setProperty("magic_number", (long)history.magic_number);
		obj.setProperty("layer", history.layer);
		obj.setProperty("status", (int)history.status);
		obj.setProperty("side", history.side);
		obj.setProperty("order_close_reason", (int)history.order_close_reason);
		obj.setProperty("main_take_profit_in_points", history.main_take_profit_in_points);
		obj.setProperty("main_stop_loss_in_points", history.main_stop_loss_in_points);
		obj.setProperty("main_take_profit_at_price", history.main_take_profit_at_price);
		obj.setProperty("main_stop_loss_at_price", history.main_stop_loss_at_price);
		obj.setProperty("signal_at", (long)history.signal_at);
		obj.setProperty("open_time", (long)history.open_time);
		obj.setProperty("open_price", history.open_price);
		obj.setProperty("open_lot", history.open_lot);
		obj.setProperty("close_time", (long)history.close_time);
		obj.setProperty("close_price", history.close_price);
		obj.setProperty("profit_in_dollars", history.profit_in_dollars);

		return obj;
	}

	JSON::Array *OrderHistoryArrayToJsonArray(const SOrderHistory &histories[], int count) {
		JSON::Array *arr = new JSON::Array();
		for (int i = 0; i < count; i++)
			arr.add(OrderHistoryToJson(histories[i]));
		return arr;
	}

public:

	ReportOfOrderHistory() {
		MqlDateTime dt = dtime.Now();
		string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
		reports_dir = "/Reports/" + _Symbol + "/" + timestamp;
		use_common_files = false;
		ArrayResize(order_history, 0);
		logger.SetPrefix("OrderHistoryReporter");
	}

	ReportOfOrderHistory(string custom_dir, bool use_common_folder = false) {
		reports_dir = custom_dir;
		use_common_files = use_common_folder;
		ArrayResize(order_history, 0);
		logger.SetPrefix("OrderHistoryReporter");
	}

	void SetReportsDirectory(string dir, bool use_common_folder = false) {
		reports_dir = dir;
		use_common_files = use_common_folder;
	}

	string GetCurrentReportsPath() {
		string path_separator = "\\";
		string converted_dir = reports_dir;
		StringReplace(converted_dir, "/", path_separator);

		if (use_common_files)
			return TerminalInfoString(TERMINAL_COMMONDATA_PATH) + path_separator + "Files" + converted_dir;
		else
			return TerminalInfoString(TERMINAL_DATA_PATH) + path_separator + "MQL5" + path_separator + "Files" + converted_dir;
	}

	void PrintCurrentPath() {
		logger.info("Order history reports saved to: " + GetCurrentReportsPath());
	}

	void AddOrderSnapshot(const SOrderHistory &snapshot) {
		ArrayResize(order_history, ArraySize(order_history) + 1);
		order_history[ArraySize(order_history) - 1] = snapshot;
	}

	void ExportOrderHistoryToJsonFile() {
		JSON::Object *root = new JSON::Object();
		root.setProperty("name", "Orders Report");

		if (ArraySize(order_history) == 0) {
			logger.warning("No order history data to export - creating empty report");
			JSON::Array *empty_array = new JSON::Array();
			root.setProperty("data", empty_array);
		} else {
			root.setProperty("data", OrderHistoryArrayToJsonArray(order_history, ArraySize(order_history)));
		}

		string json_str = root.toString();
		string filename = reports_dir + "/OrdersReport.json";

		int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;
		if (use_common_files)
			flags |= FILE_COMMON;

		logger.debug("Attempting to create order history file: " + filename);
		logger.debug("Full path: " + GetCurrentReportsPath() + "\\OrdersReport.json");
		logger.debug("Orders to export: " + IntegerToString(ArraySize(order_history)));

		int file = FileOpen(filename, flags);

		if (file == INVALID_HANDLE) {
			int error_code = GetLastError();
			logger.error("Cannot create order history file '" + filename + "' - Error code: " + IntegerToString(error_code));
			logger.error("Flags used: " + IntegerToString(flags) + " (FILE_WRITE=" + IntegerToString(FILE_WRITE) + ", FILE_TXT=" + IntegerToString(FILE_TXT) + ", FILE_ANSI=" + IntegerToString(FILE_ANSI) + ", FILE_COMMON=" + IntegerToString(FILE_COMMON) + ")");
		} else {
			FileWriteString(file, json_str);
			FileClose(file);
			logger.info("Order history saved - OrdersReport.json with " + IntegerToString(ArraySize(order_history)) + " orders");
		}

		delete root;
	}

	int GetOrderCount() {
		return ArraySize(order_history);
	}

	void ClearHistory() {
		ArrayResize(order_history, 0);
	}
};

#endif
