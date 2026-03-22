#ifndef __E_ACCOUNT_MQH__
#define __E_ACCOUNT_MQH__

#include "../libraries/Json/index.mqh"
#include "../helpers/HClampNumeric.mqh"

class EAccount {
public:
	long GetNumber() {
		return AccountInfoInteger(ACCOUNT_LOGIN);
	}

	int GetLeverage() {
		return (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
	}

	string GetBrokerName() {
		return AccountInfoString(ACCOUNT_COMPANY);
	}

	string GetBrokerServer() {
		return AccountInfoString(ACCOUNT_SERVER);
	}

	string GetCurrency() {
		return AccountInfoString(ACCOUNT_CURRENCY);
	}

	double GetBalance() {
		return AccountInfoDouble(ACCOUNT_BALANCE);
	}

	double GetEquity() {
		return AccountInfoDouble(ACCOUNT_EQUITY);
	}

	double GetMargin() {
		return AccountInfoDouble(ACCOUNT_MARGIN);
	}

	double GetFreeMargin() {
		return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
	}

	double GetMarginLevel() {
		return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
	}

	double GetSafeMarginLevel() {
		if (AccountInfoDouble(ACCOUNT_MARGIN) > 0) {
			return NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2);
		}

		return 0.0;
	}

	double GetProfit() {
		return AccountInfoDouble(ACCOUNT_PROFIT);
	}

	bool IsTradeAllowed() {
		return (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
	}

	long GetMaxOrders() {
		return AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
	}

	JSON::Array *GetMetadata() {
		JSON::Array *entries = new JSON::Array();

		addEntry(*entries, "leverage", "Leverage", IntegerToString(GetLeverage()), "integer");
		addEntry(*entries, "currency", "Currency", GetCurrency(), "string");
		addEntry(*entries, "balance", "Balance", DoubleToString(ClampNumeric(GetBalance(), 13, 2), 2), "decimal");
		addEntry(*entries, "equity", "Equity", DoubleToString(ClampNumeric(GetEquity(), 13, 2), 2), "decimal");
		addEntry(*entries, "margin", "Margin", DoubleToString(ClampNumeric(GetMargin(), 13, 2), 2), "decimal");
		addEntry(*entries, "free_margin", "Free Margin", DoubleToString(ClampNumeric(GetFreeMargin(), 13, 2), 2), "decimal");
		addEntry(*entries, "margin_level", "Margin Level", DoubleToString(ClampNumeric(GetSafeMarginLevel(), 8, 2), 2), "decimal");
		addEntry(*entries, "profit", "Profit", DoubleToString(ClampNumeric(GetProfit(), 13, 2), 2), "decimal");
		addEntry(*entries, "trade_allowed", "Trade Allowed", IsTradeAllowed() ? "true" : "false", "boolean");
		addEntry(*entries, "max_orders", "Max Orders", IntegerToString(GetMaxOrders()), "integer");

		return entries;
	}

private:
	void addEntry(JSON::Array &entries, string key, string label, string value, string format) {
		JSON::Object *entry = new JSON::Object();
		entry.setProperty("key", key);
		entry.setProperty("label", label);
		entry.setProperty("value", value);
		entry.setProperty("format", format);
		entries.add(entry);
	}
};

#endif
