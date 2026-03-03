#ifndef __HORIZON_API_MQH__
#define __HORIZON_API_MQH__

#include "../../services/SERequest/SERequest.mqh"
#include "../../services/SELogger/SELogger.mqh"
#include "../../entities/EOrder.mqh"
#include "../../interfaces/IRemoteLogger.mqh"
#include "../../helpers/HClampNumeric.mqh"
#include "../../helpers/HGenerateUuid.mqh"
#include "enums/EHeartbeatEvent.mqh"

class HorizonAPI:
public IRemoteLogger {
private:
	SERequest * request;
	SELogger logger;
	long accountId;
	bool isEnabled;

	ulong registeredMagicNumbers[];
	string registeredStrategyUUIDs[];

	string OrderStatusToString(ENUM_ORDER_STATUSES status) {
		if (status == ORDER_STATUS_PENDING) {
			return "pending";
		}

		if (status == ORDER_STATUS_OPEN) {
			return "open";
		}

		if (status == ORDER_STATUS_CLOSING) {
			return "closing";
		}

		if (status == ORDER_STATUS_CLOSED) {
			return "closed";
		}

		if (status == ORDER_STATUS_CANCELLED) {
			return "cancelled";
		}

		return "unknown";
	}

	string HeartbeatEventToString(ENUM_HEARTBEAT_EVENT event) {
		if (event == HEARTBEAT_INIT) {
			return "on_init";
		}

		if (event == HEARTBEAT_DEINIT) {
			return "on_deinit";
		}

		if (event == HEARTBEAT_RUNNING) {
			return "on_running";
		}

		if (event == HEARTBEAT_ERROR) {
			return "on_error";
		}

		return "unknown";
	}

	string OrderSideToString(int side) {
		if (side == ORDER_TYPE_BUY) {
			return "buy";
		}

		return "sell";
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
		if (reason == DEAL_REASON_TP) {
			return "tp";
		}

		if (reason == DEAL_REASON_SL) {
			return "sl";
		}

		if (reason == DEAL_REASON_EXPERT) {
			return "expert";
		}

		if (reason == DEAL_REASON_CLIENT) {
			return "client";
		}

		if (reason == DEAL_REASON_MOBILE) {
			return "mobile";
		}

		if (reason == DEAL_REASON_WEB) {
			return "web";
		}

		return "unknown";
	}

	bool authenticate(string baseUrl, string apiKey) {
		SERequest authRequest(baseUrl);
		authRequest.AddHeader("Content-Type", "application/json");

		JSON::Object loginBody;
		loginBody.setProperty("api_key", apiKey);

		SRequestResponse response = authRequest.Post("api/v1/auth/login/", loginBody, 10000);

		if (response.status != 200) {
			logger.Error(StringFormat("Authentication failed with status %d", response.status));
			return false;
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Error("Authentication response missing 'data' object");
			return false;
		}

		JSON::Object *dataObject = root.getObject("data");

		if (dataObject == NULL) {
			logger.Error("Authentication 'data' field is not an object");
			return false;
		}

		string accessToken = dataObject.getString("access");

		if (accessToken == "") {
			logger.Error("Authentication response missing 'access' token");
			return false;
		}

		request = new SERequest(baseUrl);
		request.AddHeader("Content-Type", "application/json");
		request.AddHeader("Authorization", "Bearer " + accessToken);

		return true;
	}

	void RegisterStrategy(ulong magicNumber) {
		for (int i = 0; i < ArraySize(registeredMagicNumbers); i++) {
			if (registeredMagicNumbers[i] == magicNumber) {
				return;
			}
		}

		int size = ArraySize(registeredMagicNumbers);
		ArrayResize(registeredMagicNumbers, size + 1);
		ArrayResize(registeredStrategyUUIDs, size + 1);
		registeredMagicNumbers[size] = magicNumber;
		registeredStrategyUUIDs[size] = MagicNumberToUuid(magicNumber);
	}

	string GetStrategyUUID(ulong magicNumber) {
		for (int i = 0; i < ArraySize(registeredMagicNumbers); i++) {
			if (registeredMagicNumbers[i] == magicNumber) {
				return registeredStrategyUUIDs[i];
			}
		}

		return MagicNumberToUuid(magicNumber);
	}

	void buildOrderProfitFields(JSON::Object &body, EOrder &order) {
		if (order.GetStatus() == ORDER_STATUS_CLOSED) {
			body.setProperty("profit", ClampNumeric(order.GetProfitInDollars(), 13, 2));
			body.setProperty("gross_profit", ClampNumeric(order.GetGrossProfit(), 13, 2));
			body.setProperty("commission", ClampNumeric(order.GetCommission(), 13, 2));
			body.setProperty("swap", ClampNumeric(order.GetSwap(), 13, 2));
			body.setProperty("close_reason", CloseReasonToString(order.GetCloseReason()));
		} else {
			body.setProperty("profit", ClampNumeric(order.GetFloatingPnL(), 13, 2));
		}
	}

	void buildOrderDateTimeFields(JSON::Object &body, EOrder &order) {
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
	}

public:
	HorizonAPI() {
		request = NULL;
		accountId = 0;
		isEnabled = false;
		logger.SetPrefix("HorizonAPI");
	}

	~HorizonAPI() {
		if (request != NULL && CheckPointer(request) == POINTER_DYNAMIC) {
			delete request;
		}
	}

	bool Initialize(string baseUrl, string apiKey, bool enabled) {
		if (!enabled) {
			return true;
		}

		if (apiKey == "") {
			logger.Error("API key is required. HorizonAPI integration disabled.");
			return false;
		}

		if (request != NULL && CheckPointer(request) == POINTER_DYNAMIC) {
			delete request;
			request = NULL;
		}

		accountId = AccountInfoInteger(ACCOUNT_LOGIN);

		if (!authenticate(baseUrl, apiKey)) {
			return false;
		}

		isEnabled = true;
		logger.Info("Initialized for account " + IntegerToString(accountId));
		return true;
	}

	bool IsEnabled() {
		return isEnabled;
	}

	void UpsertAccount() {
		if (!isEnabled) {
			return;
		}

		double balance = ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2);
		double equity = ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2);

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

		request.Post("api/v1/account/", body);
	}

	void UpsertStrategy(
		string strategyName,
		string symbol,
		string prefix,
		ulong magicNumber,
		double balance
	) {
		if (!isEnabled) {
			return;
		}

		RegisterStrategy(magicNumber);

		JSON::Object body;
		body.setProperty("id", GetStrategyUUID(magicNumber));
		body.setProperty("account_id", accountId);
		body.setProperty("name", strategyName);
		body.setProperty("symbol", symbol);
		body.setProperty("prefix", prefix);
		body.setProperty("magic_number", (long)magicNumber);
		body.setProperty("balance", ClampNumeric(balance, 13, 2));

		request.Post("api/v1/strategy/", body);
	}

	void StoreHeartbeat(ulong magicNumber, ENUM_HEARTBEAT_EVENT event, string system = "strategy") {
		if (!isEnabled) {
			return;
		}

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("strategy_id", GetStrategyUUID(magicNumber));
		body.setProperty("event", HeartbeatEventToString(event));
		body.setProperty("system", system);

		request.Post("api/v1/heartbeat/", body);
	}

	void UpsertOrder(EOrder &order) {
		if (!isEnabled) {
			return;
		}

		JSON::Object body;
		body.setProperty("id", order.GetId());
		body.setProperty("account_id", accountId);
		body.setProperty("strategy_id", GetStrategyUUID(order.GetMagicNumber()));
		body.setProperty("ticket", (long)order.GetOrderId());
		body.setProperty("deal_id", (long)order.GetDealId());
		body.setProperty("position_id", (long)order.GetPositionId());
		body.setProperty("source", order.GetSource());
		body.setProperty("symbol", order.GetSymbol());
		body.setProperty("side", OrderSideToString(order.GetSide()));
		body.setProperty("status", OrderStatusToString(order.GetStatus()));
		body.setProperty("is_market_order", order.IsMarketOrder());
		body.setProperty("volume", ClampNumeric(order.GetVolume(), 6, 4));
		body.setProperty("signal_price", ClampNumeric(order.GetSignalPrice(), 10, 5));
		body.setProperty("open_at_price", ClampNumeric(order.GetOpenAtPrice(), 10, 5));
		body.setProperty("open_price", ClampNumeric(order.GetOpenPrice(), 10, 5));
		body.setProperty("close_price", ClampNumeric(order.GetClosePrice(), 10, 5));
		body.setProperty("take_profit", ClampNumeric(order.GetTakeProfitPrice(), 10, 5));
		body.setProperty("stop_loss", ClampNumeric(order.GetStopLossPrice(), 10, 5));
		buildOrderProfitFields(body, order);
		buildOrderDateTimeFields(body, order);

		request.Post("api/v1/order/", body);
	}

	void StoreLog(string level, string message, ulong magicNumber = 0) {
		if (!isEnabled) {
			return;
		}

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("level", level);
		body.setProperty("message", message);

		if (magicNumber > 0) {
			body.setProperty("strategy_id", GetStrategyUUID(magicNumber));
		}

		request.Post("api/v1/log/", body);
	}

	void StoreAccountSnapshot(
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots
	) {
		if (!isEnabled) {
			return;
		}

		double balance = ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2);
		double equity = ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2);

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("balance", balance);
		body.setProperty("equity", equity);
		body.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
		body.setProperty("margin_level", ClampNumeric(GetSafeMarginLevel(), 8, 2));
		body.setProperty("open_positions", PositionsTotal());
		body.setProperty("drawdown_pct", ClampNumeric(drawdownPct, 4, 4));
		body.setProperty("daily_pnl", ClampNumeric(dailyPnl, 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("open_order_count", openOrderCount);
		body.setProperty("exposure_lots", ClampNumeric(exposureLots, 6, 4));

		request.Post("api/v1/account-snapshot/", body);
	}

	void StoreStrategySnapshot(
		ulong magicNumber,
		double nav,
		double drawdownPct,
		double dailyPnl,
		double floatingPnl,
		int openOrderCount,
		double exposureLots
	) {
		if (!isEnabled) {
			return;
		}

		JSON::Object body;
		body.setProperty("account_id", accountId);
		body.setProperty("strategy_id", GetStrategyUUID(magicNumber));
		body.setProperty("nav", ClampNumeric(nav, 13, 2));
		body.setProperty("drawdown_pct", ClampNumeric(drawdownPct, 4, 4));
		body.setProperty("daily_pnl", ClampNumeric(dailyPnl, 13, 2));
		body.setProperty("floating_pnl", ClampNumeric(floatingPnl, 13, 2));
		body.setProperty("open_order_count", openOrderCount);
		body.setProperty("exposure_lots", ClampNumeric(exposureLots, 6, 4));

		request.Post("api/v1/strategy-snapshot/", body);
	}
};

#endif
