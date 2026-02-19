#ifndef __WARROOM_MQH__
#define __WARROOM_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../entities/EOrder.mqh"
#include "../../interfaces/IRemoteLogger.mqh"
#include "../../helpers/HClampNumeric.mqh"
#include "enums/EHeartbeatEvent.mqh"

class WARRoom:
public IRemoteLogger {
private:
	SERequest * request;
	SELogger logger;
	long accountId;
	bool isEnabled;
	string upsertHeader;

	string OrderStatusToString(ENUM_ORDER_STATUSES status) {
		switch (status) {
		case ORDER_STATUS_PENDING:   return "pending";
		case ORDER_STATUS_OPEN:      return "open";
		case ORDER_STATUS_CLOSING:   return "closing";
		case ORDER_STATUS_CLOSED:    return "closed";
		case ORDER_STATUS_CANCELLED: return "cancelled";
		}

		return "unknown";
	}

	string HeartbeatEventToString(ENUM_HEARTBEAT_EVENT event) {
		switch (event) {
		case HEARTBEAT_INIT:       return "init";
		case HEARTBEAT_DEINIT:     return "deinit";
		case HEARTBEAT_ONLINE:     return "online";
		case HEARTBEAT_START_DAY:  return "start_day";
		case HEARTBEAT_START_HOUR: return "start_hour";
		case HEARTBEAT_ERROR:      return "error";
		}

		return "unknown";
	}

	double GetSafeMarginLevel() {
		if (AccountInfoDouble(ACCOUNT_MARGIN) > 0) {
			return NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2);
		}

		return 0.0;
	}

	bool IsValidDateTime(SDateTime &dt) {
		return dt.timestamp > 0 && dt.year >= 2020 && dt.year <= 2100;
	}

	string CloseReasonToString(ENUM_DEAL_REASON reason) {
		switch (reason) {
		case DEAL_REASON_TP:      return "tp";
		case DEAL_REASON_SL:      return "sl";
		case DEAL_REASON_EXPERT:  return "expert";
		case DEAL_REASON_CLIENT:  return "client";
		case DEAL_REASON_MOBILE:  return "mobile";
		case DEAL_REASON_WEB:     return "web";
		}

		return "unknown";
	}

public:
	WARRoom() {
		request = NULL;
		accountId = 0;
		isEnabled = false;
		upsertHeader = "Prefer: resolution=merge-duplicates\r\n";
		logger.SetPrefix("WARRoom");
	}

	~WARRoom() {
		if (request != NULL && CheckPointer(request) == POINTER_DYNAMIC) {
			delete request;
		}
	}

	bool Initialize(string baseUrl, string apiKey, bool enabled) {
		if (!enabled) {
			return true;
		}

		if (apiKey == "") {
			logger.Error("API key is required. WARRoom integration disabled.");
			return false;
		}

		if (request != NULL && CheckPointer(request) == POINTER_DYNAMIC) {
			delete request;
		}

		accountId = AccountInfoInteger(ACCOUNT_LOGIN);
		request = new SERequest(baseUrl);
		request.AddHeader("Content-Type", "application/json");
		request.AddHeader("Authorization", "Bearer " + apiKey);

		isEnabled = true;
		logger.Info("Initialized for account " + IntegerToString(accountId));
		return true;
	}

	bool IsEnabled() {
		return isEnabled;
	}

	void InsertOrUpdateAccount() {
		if (!isEnabled) {
			return;
		}

		double balance = ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2);
		double equity = ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2);

		logger.Info(StringFormat("Sync account balance=%.2f equity=%.2f", balance, equity));

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("broker", AccountInfoString(ACCOUNT_COMPANY));
		body.setProperty("server", AccountInfoString(ACCOUNT_SERVER));
		body.setProperty("currency", AccountInfoString(ACCOUNT_CURRENCY));
		body.setProperty("leverage", (int)AccountInfoInteger(ACCOUNT_LEVERAGE));
		body.setProperty("balance", balance);
		body.setProperty("equity", equity);
		body.setProperty("margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN), 13, 2));
		body.setProperty("free_margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 13, 2));
		body.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
		body.setProperty("margin_level", ClampNumeric(GetSafeMarginLevel(), 8, 2));

		request.Post("accounts", body, 0, upsertHeader);
	}

	void InsertOrUpdateStrategy(
		string strategyName,
		string symbol,
		string prefix,
		ulong magicNumber,
		double weight,
		double balance
	) {
		if (!isEnabled) {
			return;
		}

		logger.Info(StringFormat("Sync strategy %s balance=%.2f", strategyName, balance));

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("name", strategyName);
		body.setProperty("symbol", symbol);
		body.setProperty("prefix", prefix);
		body.setProperty("magic_number", (long)magicNumber);
		body.setProperty("weight", ClampNumeric(weight, 6, 4));
		body.setProperty("balance", ClampNumeric(balance, 13, 2));

		request.Post("strategies?on_conflict=magic_number", body, 0, upsertHeader);
	}

	void InsertHeartbeat(ulong magicNumber, ENUM_HEARTBEAT_EVENT event) {
		if (!isEnabled) {
			return;
		}

		string eventString = HeartbeatEventToString(event);

		logger.Info(StringFormat("Heartbeat event=%s magic=%llu", eventString, magicNumber));

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("magic_number", (long)magicNumber);
		body.setProperty("event", eventString);

		request.Post("heartbeats", body);
	}

	void InsertOrUpdateOrder(EOrder &order) {
		if (!isEnabled) {
			return;
		}

		logger.Info(StringFormat("Sync order %s status=%s ticket=%llu",
			order.GetId(), OrderStatusToString(order.GetStatus()), order.GetOrderId()));

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("ticket", (long)order.GetOrderId());
		body.setProperty("deal_id", (long)order.GetDealId());
		body.setProperty("position_id", (long)order.GetPositionId());
		body.setProperty("magic_number", (long)order.GetMagicNumber());
		body.setProperty("source", order.GetSource());
		body.setProperty("symbol", order.GetSymbol());
		body.setProperty("side", order.GetSide());
		body.setProperty("status", OrderStatusToString(order.GetStatus()));
		body.setProperty("is_market_order", order.IsMarketOrder());
		body.setProperty("volume", ClampNumeric(order.GetVolume(), 6, 4));
		body.setProperty("signal_price", ClampNumeric(order.GetSignalPrice(), 10, 5));
		body.setProperty("open_at_price", ClampNumeric(order.GetOpenAtPrice(), 10, 5));
		body.setProperty("open_price", ClampNumeric(order.GetOpenPrice(), 10, 5));
		body.setProperty("close_price", ClampNumeric(order.GetClosePrice(), 10, 5));
		body.setProperty("take_profit", ClampNumeric(order.GetTakeProfitPrice(), 10, 5));
		body.setProperty("stop_loss", ClampNumeric(order.GetStopLossPrice(), 10, 5));
		if (order.GetStatus() == ORDER_STATUS_CLOSED) {
			body.setProperty("profit", ClampNumeric(order.GetProfitInDollars(), 13, 2));
			body.setProperty("close_reason", CloseReasonToString(order.GetCloseReason()));
		} else {
			body.setProperty("profit", ClampNumeric(order.GetFloatingPnL(), 13, 2));
		}

		SDateTime signalTime = order.GetSignalAt();
		SDateTime openTime = order.GetOpenAt();
		SDateTime closeTime = order.GetCloseAt();

		if (IsValidDateTime(signalTime)) {
			body.setProperty("signal_at", signalTime.ToUTCISO());
		}

		if (IsValidDateTime(openTime)) {
			body.setProperty("opened_at", openTime.ToUTCISO());
		}

		if (IsValidDateTime(closeTime)) {
			body.setProperty("closed_at", closeTime.ToUTCISO());
		}

		request.Post("orders?on_conflict=ticket", body, 0, upsertHeader);
	}

	void InsertLog(string level, string message, ulong magicNumber = 0) {
		if (!isEnabled) {
			return;
		}

		logger.Info(StringFormat("Send log level=%s", level));

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("level", level);
		body.setProperty("message", message);

		if (magicNumber > 0) {
			body.setProperty("magic_number", (long)magicNumber);
		}

		request.Post("logs", body);
	}

	void InsertAccountSnapshot() {
		if (!isEnabled) {
			return;
		}

		double balance = ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2);
		double equity = ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2);

		logger.Info(StringFormat("Snapshot balance=%.2f equity=%.2f", balance, equity));

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("balance", balance);
		body.setProperty("equity", equity);
		body.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
		body.setProperty("margin_level", ClampNumeric(GetSafeMarginLevel(), 8, 2));

		request.Post("account_snapshots", body);
	}
};

#endif
