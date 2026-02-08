#ifndef __SE_ORDER_PERSISTENCE_MQH__
#define __SE_ORDER_PERSISTENCE_MQH__

#include "../../libraries/json/index.mqh"
#include "../../helpers/HIsLiveTrading.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../../entities/EOrder.mqh"

extern SEDateTime dtime;

class SEOrderPersistence {
private:
	SELogger logger;

	string basePath;

	bool CreateDirectoryStructure(string strategyName) {
		string symbolPath = StringFormat("%s/%s", basePath, _Symbol);
		string strategyPath = StringFormat("%s/%s", symbolPath, strategyName);
		string ordersPath = StringFormat("%s/orders", strategyPath);

		string paths[] = { symbolPath, strategyPath, ordersPath };

		for (int i = 0; i < ArraySize(paths); i++) {
			string keepFile = StringFormat("%s/.keep", paths[i]);
			int handle = FileOpen(keepFile, FILE_WRITE | FILE_TXT | FILE_COMMON);

			if (handle == INVALID_HANDLE)
				return false;

			FileClose(handle);
			FileDelete(keepFile, FILE_COMMON);
		}

		return true;
	}

	bool DeserializeOrder(string jsonData, EOrder &order) {
		JSON::Object json(jsonData);

		if (!json.hasValue("id")) {
			logger.error("Failed to deserialize order JSON");
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

		order.SetId(json.getString("id"));
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
		order.takeProfitPrice = json.getNumber("take_profit_price");
		order.stopLossPrice = json.getNumber("stop_loss_price");

		SDateTime signalAt = dtime.FromTimestamp((datetime)json.getNumber("signal_at"));
		SDateTime openAt = dtime.FromTimestamp((datetime)json.getNumber("open_at"));
		order.SetSignalAt(signalAt);
		order.SetOpenAt(openAt);

		return true;
	}

	string GetOrderFilePath(string strategyName, string orderId) {
		string safeOrderId = SanitizeFileName(orderId);
		return StringFormat("%s/%s/%s/orders/%s.json", basePath, _Symbol, strategyName, safeOrderId);
	}

	string GetStrategyOrdersPath(string strategyName) {
		return StringFormat("%s/%s/%s/orders/", basePath, _Symbol, strategyName);
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

		json.setProperty("is_initialized", order.IsInitialized());
		json.setProperty("is_processed", order.IsProcessed());
		json.setProperty("is_market_order", order.IsMarketOrder());
		json.setProperty("pending_to_open", order.IsPendingToOpen());
		json.setProperty("pending_to_close", order.IsPendingToClose());
		json.setProperty("retry_count", order.GetRetryCount());
		json.setProperty("retry_after", (long)order.GetRetryAfter());
		json.setProperty("status", (int)order.GetStatus());

		json.setProperty("id", order.GetId());
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
		json.setProperty("take_profit_price", order.takeProfitPrice);
		json.setProperty("stop_loss_price", order.stopLossPrice);

		json.setProperty("signal_at", (long)order.GetSignalAt().timestamp);
		json.setProperty("open_at", (long)order.GetOpenAt().timestamp);

		json.setProperty("saved_at", (long)dtime.Timestamp());

		return json.toString();
	}

public:
	SEOrderPersistence() {
		logger.SetPrefix("OrderPersistence");
		basePath = "Horizon5";
	}

	bool DeleteOrderJson(string strategyName, string orderId) {
		if (!isLiveTrading())
			return true;

		string filePath = GetOrderFilePath(strategyName, orderId);

		if (!FileDelete(filePath, FILE_COMMON)) {
			int error = GetLastError();

			if (error != ERR_FILE_NOT_EXIST) {
				logger.error(StringFormat(
					" Cannot delete order file: %s Error: %d",
					filePath,
					error
				));

				return false;
			}
		}

		logger.info(StringFormat("Order JSON deleted: %s", filePath));
		return true;
	}

	int LoadOrdersFromJson(string strategyName, EOrder &restoredOrders[]) {
		if (!isLiveTrading())
			return 0;

		logger.info(StringFormat("Starting order restoration for strategy: %s", strategyName));

		string ordersPath = GetStrategyOrdersPath(strategyName);
		string searchPattern = StringFormat("%s*.json", ordersPath);
		string fileName;

		long searchHandle = FileFindFirst(searchPattern, fileName, FILE_COMMON);
		if (searchHandle == INVALID_HANDLE) {
			logger.info(StringFormat("No order files found for strategy: %s", strategyName));
			return 0;
		}

		int loadedCount = 0;
		int processedFiles = 0;

		do {
			processedFiles++;

			if (StringFind(fileName, "._") == 0 || StringFind(fileName, ".") == 0) {
				logger.info(StringFormat("Skipping system file: %s", fileName));
				continue;
			}

			if (StringFind(fileName, ".json") == -1) {
				logger.info(StringFormat("Skipping non-JSON file: %s", fileName));
				continue;
			}

			logger.info(StringFormat("Processing order file: %s", fileName));
			string fullPath = ordersPath + fileName;
			int handle = FileOpen(fullPath, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);

			if (handle != INVALID_HANDLE) {
				string jsonData = "";
				EOrder order;

				while (!FileIsEnding(handle))
					jsonData += FileReadString(handle);

				FileClose(handle);

				if (DeserializeOrder(jsonData, order)) {
					if (ValidateOrderExists(order)) {
						ArrayResize(restoredOrders, ArraySize(restoredOrders) + 1);
						restoredOrders[ArraySize(restoredOrders) - 1] = order;
						loadedCount++;

						logger.info(StringFormat(
							"Order loaded successfully: %s (Status: %s)",
							order.GetId(),
							EnumToString(order.GetStatus())
						));
					} else {
						logger.warning(StringFormat(
							" Order no longer exists in MetaTrader, cleaning up: %s",
							order.GetId()
						));

						DeleteOrderJson(strategyName, order.GetId());
					}
				} else {
					logger.error(StringFormat(
						"CRITICAL ERROR: Failed to deserialize order from: %s",
						fileName
					));

					logger.info(StringFormat("JSON data length: %d", StringLen(jsonData)));
					logger.info(StringFormat("First 100 chars: %s", StringSubstr(jsonData, 0, 100)));
					FileFindClose(searchHandle);
					return -1;
				}
			} else {
				logger.error(StringFormat(
					"CRITICAL ERROR: Cannot open file: %s Error: %d",
					fileName,
					GetLastError()
				));

				FileFindClose(searchHandle);
				return -1;
			}
		} while (FileFindNext(searchHandle, fileName));

		FileFindClose(searchHandle);

		logger.info(StringFormat("Order restoration completed for strategy: %s", strategyName));
		logger.info(StringFormat("Files processed: %d", processedFiles));
		logger.info(StringFormat("Orders loaded: %d", loadedCount));
		return loadedCount;
	}

	bool SaveOrderToJson(EOrder &order) {
		if (!isLiveTrading())
			return true;

		if (!CreateDirectoryStructure(order.GetSource())) {
			logger.error(StringFormat("Cannot create directory structure for strategy: %s", order.GetSource()));
			return false;
		}

		string filePath = GetOrderFilePath(order.GetSource(), order.GetId());
		string jsonData = SerializeOrder(order);

		int handle = FileOpen(filePath, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
		if (handle == INVALID_HANDLE) {
			logger.error(StringFormat(
				" Cannot create order file: %s Error: %d",
				filePath,
				GetLastError()
			));

			return false;
		}

		FileWriteString(handle, jsonData);
		FileFlush(handle);
		FileClose(handle);

		logger.info(StringFormat("Order saved to JSON: %s", filePath));
		return true;
	}

	bool ValidateOrderExists(EOrder &order) {
		if (!isLiveTrading())
			return true;

		if (order.GetStatus() == ORDER_STATUS_PENDING && order.GetOrderId() > 0)
			return OrderSelect(order.GetOrderId());

		if (order.GetStatus() == ORDER_STATUS_OPEN && order.GetPositionId() > 0)
			return PositionSelectByTicket(order.GetPositionId());

		return false;
	}
};

#endif
