#ifndef __ORDER_PERSISTENCE_MQH__
#define __ORDER_PERSISTENCE_MQH__

class OrderPersistence {
private:
	string base_path;
	Logger logger;

	string SanitizeFileName(string filename) {
		string result = filename;
		StringReplace(result, ":", "_");
		StringReplace(result, "/", "_");
		StringReplace(result, "\\", "_");
		StringReplace(result, "*", "_");
		StringReplace(result, "?", "_");
		StringReplace(result, "\"", "_");
		StringReplace(result, "<", "_");
		StringReplace(result, ">", "_");
		StringReplace(result, "|", "_");
		return result;
	}

	string GetOrderFilePath(string strategy_name, string order_id) {
		string safe_order_id = SanitizeFileName(order_id);
		return base_path + "/" + _Symbol + "/" + strategy_name + "/orders/" + safe_order_id + ".json";
	}

	string GetStrategyOrdersPath(string strategy_name) {
		return base_path + "/" + _Symbol + "/" + strategy_name + "/orders/";
	}

	bool CreateDirectoryStructure(string strategy_name) {
		string symbol_path = base_path + "/" + _Symbol;
		string strategy_path = symbol_path + "/" + strategy_name;
		string orders_path = strategy_path + "/orders";


		int handle = FileOpen(symbol_path + "/.keep", FILE_WRITE | FILE_TXT | FILE_COMMON);
		if (handle != INVALID_HANDLE)
			FileClose(handle);

		handle = FileOpen(strategy_path + "/.keep", FILE_WRITE | FILE_TXT | FILE_COMMON);
		if (handle != INVALID_HANDLE)
			FileClose(handle);


		handle = FileOpen(orders_path + "/.keep", FILE_WRITE | FILE_TXT | FILE_COMMON);
		if (handle != INVALID_HANDLE) {
			FileClose(handle);
			return true;
		}

		return false;
	}

	string SerializeOrder(Order &order) {
		JSON::Object json;

		json.setProperty("is_initialized", order.is_initialized);
		json.setProperty("is_processed", order.is_processed);
		json.setProperty("is_market_order", order.is_market_order);
		json.setProperty("status", (int)order.status);

		json.setProperty("id", order.id);
		json.setProperty("source", order.source);
		json.setProperty("source_custom_id", order.source_custom_id);
		json.setProperty("side", order.side);
		json.setProperty("layer", order.layer);
		json.setProperty("order_id", (long)order.order_id);
		json.setProperty("deal_id", (long)order.deal_id);
		json.setProperty("position_id", (long)order.position_id);

		json.setProperty("volume", order.volume);
		json.setProperty("signal_price", order.signal_price);
		json.setProperty("open_at_price", order.open_at_price);
		json.setProperty("open_price", order.open_price);

		json.setProperty("signal_at", (long)StructToTime(order.signal_at));
		json.setProperty("open_at", (long)StructToTime(order.open_at));

		json.setProperty("saved_at", (long)TimeCurrent());

		return json.toString();
	}

	bool DeserializeOrder(string json_data, Order &order) {
		JSON::Object json(json_data);

		if (!json.hasValue("id")) {
			logger.error("Failed to deserialize order JSON");
			return false;
		}

		order.is_initialized = json.getBoolean("is_initialized");
		order.is_processed = json.getBoolean("is_processed");
		order.is_market_order = json.getBoolean("is_market_order");
		order.status = (ENUM_ORDER_STATUSES)json.getNumber("status");

		order.id = json.getString("id");
		order.source = json.getString("source");
		order.source_custom_id = json.getString("source_custom_id");
		order.side = (int)json.getNumber("side");
		order.layer = (int)json.getNumber("layer");
		order.order_id = (ulong)json.getNumber("order_id");
		order.deal_id = (ulong)json.getNumber("deal_id");
		order.position_id = (ulong)json.getNumber("position_id");

		order.volume = json.getNumber("volume");
		order.signal_price = json.getNumber("signal_price");
		order.open_at_price = json.getNumber("open_at_price");
		order.open_price = json.getNumber("open_price");

		TimeToStruct((datetime)json.getNumber("signal_at"), order.signal_at);
		TimeToStruct((datetime)json.getNumber("open_at"), order.open_at);

		return true;
	}

public:
	OrderPersistence() {
		base_path = "Live";
		logger.SetPrefix("OrderPersistence");
	}

	bool SaveOrderToJson(Order &order) {
		if (!isLiveTrading())
			return true;

		if (!CreateDirectoryStructure(order.source)) {
			logger.error("Cannot create directory structure for strategy: " + order.source);
			return false;
		}

		string file_path = GetOrderFilePath(order.source, order.Id());
		string json_data = SerializeOrder(order);

		int handle = FileOpen(file_path, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
		if (handle == INVALID_HANDLE) {
			logger.error(" Cannot create order file: " + file_path + " Error: " + IntegerToString(GetLastError()));
			return false;
		}

		FileWriteString(handle, json_data);
		FileFlush(handle);
		FileClose(handle);

		logger.info("Order saved to JSON: " + file_path);
		return true;
	}

	bool DeleteOrderJson(string strategy_name, string order_id) {
		if (!isLiveTrading())
			return true;

		string file_path = GetOrderFilePath(strategy_name, order_id);

		if (!FileDelete(file_path, FILE_COMMON)) {
			int error = GetLastError();
			if (error != ERR_FILE_NOT_EXIST) {
				logger.error(" Cannot delete order file: " + file_path + " Error: " + IntegerToString(error));
				return false;
			}
		}

		logger.info("Order JSON deleted: " + file_path);
		return true;
	}

	int LoadOrdersFromJson(string strategy_name, Order &restored_orders[]) {
		if (!isLiveTrading())
			return 0;

		logger.info("Starting order restoration for strategy: " + strategy_name);

		string orders_path = GetStrategyOrdersPath(strategy_name);
		string search_pattern = orders_path + "*.json";

		string file_name;
		long search_handle = FileFindFirst(search_pattern, file_name, FILE_COMMON);
		if (search_handle == INVALID_HANDLE) {
			logger.info("No order files found for strategy: " + strategy_name);
			return 0;
		}

		int loaded_count = 0;
		int processed_files = 0;

		do {
			processed_files++;

			if (StringFind(file_name, "._") == 0 || StringFind(file_name, ".") == 0) {
				logger.info("Skipping system file: " + file_name);
				continue;
			}

			if (StringFind(file_name, ".json") == -1) {
				logger.info("Skipping non-JSON file: " + file_name);
				continue;
			}

			logger.info("Processing order file: " + file_name);
			string full_path = orders_path + file_name;
			int handle = FileOpen(full_path, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);

			if (handle != INVALID_HANDLE) {
				string json_data = "";
				while (!FileIsEnding(handle))
					json_data += FileReadString(handle);
				FileClose(handle);

				Order order;
				if (DeserializeOrder(json_data, order)) {
					if (ValidateOrderExists(order)) {
						ArrayResize(restored_orders, ArraySize(restored_orders) + 1);
						restored_orders[ArraySize(restored_orders) - 1] = order;
						loaded_count++;
						logger.info("Order loaded successfully: " + order.Id() + " (Status: " + EnumToString((ENUM_ORDER_STATUSES)order.status) + ")");
					} else {
						logger.warning(" Order no longer exists in MetaTrader, cleaning up: " + order.Id());
						DeleteOrderJson(strategy_name, order.Id());
					}
				} else {
					logger.error("CRITICAL ERROR: Failed to deserialize order from: " + file_name);
					logger.info("JSON data length: " + IntegerToString(StringLen(json_data)));
					logger.info("First 100 chars: " + StringSubstr(json_data, 0, 100));
					FileFindClose(search_handle);
					return -1;
				}
			} else {
				logger.error("CRITICAL ERROR: Cannot open file: " + file_name + " Error: " + IntegerToString(GetLastError()));
				FileFindClose(search_handle);
				return -1;
			}
		} while (FileFindNext(search_handle, file_name));

		FileFindClose(search_handle);

		logger.info("Order restoration completed for strategy: " + strategy_name);
		logger.info("Files processed: " + IntegerToString(processed_files));
		logger.info("Orders loaded: " + IntegerToString(loaded_count));
		return loaded_count;
	}

	bool ValidateOrderExists(Order &order) {
		if (!isLiveTrading())
			return true;

		if (order.status == ORDER_STATUS_PENDING && order.order_id > 0)
			return OrderSelect(order.order_id);

		if (order.status == ORDER_STATUS_OPEN && order.position_id > 0)
			return PositionSelectByTicket(order.position_id);

		return false;
	}

	void CleanupInvalidOrders(string strategy_name) {
		if (!isLiveTrading())
			return;

		logger.info("CleanupInvalidOrders called for strategy: " + strategy_name + " (validation now done automatically)");
	}

private:
};

#endif
