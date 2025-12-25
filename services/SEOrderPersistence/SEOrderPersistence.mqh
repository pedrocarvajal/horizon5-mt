#ifndef __SE_ORDER_PERSISTENCE_MQH__
#define __SE_ORDER_PERSISTENCE_MQH__

#include "../../libraries/json/index.mqh"
#include "../../helpers/HIsLiveTrading.mqh"
#include "../SELogger/SELogger.mqh"
#include "../../entities/EOrder.mqh"

class SEOrderPersistence {
private:
	SELogger logger;

	string basePath;

	bool CreateDirectoryStructure(string strategyName) {
		string symbolPath = basePath + "/" + _Symbol;
		string strategyPath = symbolPath + "/" + strategyName;
		string ordersPath = strategyPath + "/orders";

		int handle = FileOpen(symbolPath + "/.keep", FILE_WRITE | FILE_TXT | FILE_COMMON);
		if (handle != INVALID_HANDLE)
			FileClose(handle);

		handle = FileOpen(strategyPath + "/.keep", FILE_WRITE | FILE_TXT | FILE_COMMON);
		if (handle != INVALID_HANDLE)
			FileClose(handle);

		handle = FileOpen(ordersPath + "/.keep", FILE_WRITE | FILE_TXT | FILE_COMMON);
		if (handle != INVALID_HANDLE) {
			FileClose(handle);
			return true;
		}

		return false;
	}

	bool DeserializeOrder(string jsonData, EOrder &order) {
		JSON::Object json(jsonData);

		if (!json.hasValue("id")) {
			logger.error("Failed to deserialize order JSON");
			return false;
		}

		order.isInitialized = json.getBoolean("is_initialized");
		order.isProcessed = json.getBoolean("is_processed");
		order.isMarketOrder = json.getBoolean("is_market_order");
		order.status = (ENUM_ORDER_STATUSES)json.getNumber("status");

		order.id = json.getString("id");
		order.source = json.getString("source");
		order.sourceCustomId = json.getString("source_custom_id");
		order.side = (int)json.getNumber("side");
		order.layer = (int)json.getNumber("layer");
		order.orderId = (ulong)json.getNumber("order_id");
		order.dealId = (ulong)json.getNumber("deal_id");
		order.positionId = (ulong)json.getNumber("position_id");

		order.volume = json.getNumber("volume");
		order.signalPrice = json.getNumber("signal_price");
		order.openAtPrice = json.getNumber("open_at_price");
		order.openPrice = json.getNumber("open_price");

		TimeToStruct((datetime)json.getNumber("signal_at"), order.signalAt);
		TimeToStruct((datetime)json.getNumber("open_at"), order.openAt);

		return true;
	}

	string GetOrderFilePath(string strategyName, string orderId) {
		string safeOrderId = SanitizeFileName(orderId);
		return basePath + "/" + _Symbol + "/" + strategyName + "/orders/" + safeOrderId + ".json";
	}

	string GetStrategyOrdersPath(string strategyName) {
		return basePath + "/" + _Symbol + "/" + strategyName + "/orders/";
	}

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

	string SerializeOrder(EOrder &order) {
		JSON::Object json;

		json.setProperty("is_initialized", order.isInitialized);
		json.setProperty("is_processed", order.isProcessed);
		json.setProperty("is_market_order", order.isMarketOrder);
		json.setProperty("status", (int)order.status);

		json.setProperty("id", order.id);
		json.setProperty("source", order.source);
		json.setProperty("source_custom_id", order.sourceCustomId);
		json.setProperty("side", order.side);
		json.setProperty("layer", order.layer);
		json.setProperty("order_id", (long)order.orderId);
		json.setProperty("deal_id", (long)order.dealId);
		json.setProperty("position_id", (long)order.positionId);

		json.setProperty("volume", order.volume);
		json.setProperty("signal_price", order.signalPrice);
		json.setProperty("open_at_price", order.openAtPrice);
		json.setProperty("open_price", order.openPrice);

		json.setProperty("signal_at", (long)StructToTime(order.signalAt));
		json.setProperty("open_at", (long)StructToTime(order.openAt));

		json.setProperty("saved_at", (long)dtime.GetCurrentTime());

		return json.toString();
	}

public:
	SEOrderPersistence() {
		logger.SetPrefix("OrderPersistence");

		basePath = "Live";
	}

	bool DeleteOrderJson(string strategyName, string orderId) {
		if (!isLiveTrading())
			return true;

		string filePath = GetOrderFilePath(strategyName, orderId);

		if (!FileDelete(filePath, FILE_COMMON)) {
			int error = GetLastError();
			if (error != ERR_FILE_NOT_EXIST) {
				logger.error(" Cannot delete order file: " + filePath + " Error: " + IntegerToString(error));
				return false;
			}
		}

		logger.info("Order JSON deleted: " + filePath);
		return true;
	}

	int LoadOrdersFromJson(string strategyName, EOrder &restoredOrders[]) {
		if (!isLiveTrading())
			return 0;

		logger.info("Starting order restoration for strategy: " + strategyName);

		string ordersPath = GetStrategyOrdersPath(strategyName);
		string searchPattern = ordersPath + "*.json";

		string fileName;
		long searchHandle = FileFindFirst(searchPattern, fileName, FILE_COMMON);
		if (searchHandle == INVALID_HANDLE) {
			logger.info("No order files found for strategy: " + strategyName);
			return 0;
		}

		int loadedCount = 0;
		int processedFiles = 0;

		do {
			processedFiles++;

			if (StringFind(fileName, "._") == 0 || StringFind(fileName, ".") == 0) {
				logger.info("Skipping system file: " + fileName);
				continue;
			}

			if (StringFind(fileName, ".json") == -1) {
				logger.info("Skipping non-JSON file: " + fileName);
				continue;
			}

			logger.info("Processing order file: " + fileName);
			string fullPath = ordersPath + fileName;
			int handle = FileOpen(fullPath, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);

			if (handle != INVALID_HANDLE) {
				string jsonData = "";
				while (!FileIsEnding(handle))
					jsonData += FileReadString(handle);
				FileClose(handle);

				EOrder order;
				if (DeserializeOrder(jsonData, order)) {
					if (ValidateOrderExists(order)) {
						ArrayResize(restoredOrders, ArraySize(restoredOrders) + 1);
						restoredOrders[ArraySize(restoredOrders) - 1] = order;
						loadedCount++;
						logger.info("Order loaded successfully: " + order.Id() + " (Status: " + EnumToString((ENUM_ORDER_STATUSES)order.status) + ")");
					} else {
						logger.warning(" Order no longer exists in MetaTrader, cleaning up: " + order.Id());
						DeleteOrderJson(strategyName, order.Id());
					}
				} else {
					logger.error("CRITICAL ERROR: Failed to deserialize order from: " + fileName);
					logger.info("JSON data length: " + IntegerToString(StringLen(jsonData)));
					logger.info("First 100 chars: " + StringSubstr(jsonData, 0, 100));
					FileFindClose(searchHandle);
					return -1;
				}
			} else {
				logger.error("CRITICAL ERROR: Cannot open file: " + fileName + " Error: " + IntegerToString(GetLastError()));
				FileFindClose(searchHandle);
				return -1;
			}
		} while (FileFindNext(searchHandle, fileName));

		FileFindClose(searchHandle);

		logger.info("Order restoration completed for strategy: " + strategyName);
		logger.info("Files processed: " + IntegerToString(processedFiles));
		logger.info("Orders loaded: " + IntegerToString(loadedCount));
		return loadedCount;
	}

	bool SaveOrderToJson(EOrder &order) {
		if (!isLiveTrading())
			return true;

		if (!CreateDirectoryStructure(order.source)) {
			logger.error("Cannot create directory structure for strategy: " + order.source);
			return false;
		}

		string filePath = GetOrderFilePath(order.source, order.Id());
		string jsonData = SerializeOrder(order);

		int handle = FileOpen(filePath, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
		if (handle == INVALID_HANDLE) {
			logger.error(" Cannot create order file: " + filePath + " Error: " + IntegerToString(GetLastError()));
			return false;
		}

		FileWriteString(handle, jsonData);
		FileFlush(handle);
		FileClose(handle);

		logger.info("Order saved to JSON: " + filePath);
		return true;
	}

	bool ValidateOrderExists(EOrder &order) {
		if (!isLiveTrading())
			return true;

		if (order.status == ORDER_STATUS_PENDING && order.orderId > 0)
			return OrderSelect(order.orderId);

		if (order.status == ORDER_STATUS_OPEN && order.positionId > 0)
			return PositionSelectByTicket(order.positionId);

		return false;
	}
};

#endif
