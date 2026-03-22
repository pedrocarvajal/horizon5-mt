#ifndef __E_ASSET_MQH__
#define __E_ASSET_MQH__

#include "../libraries/Json/index.mqh"
#include "../helpers/HClampNumeric.mqh"

class EAsset {
private:
	string symbolName;

public:
	EAsset() {
		symbolName = "";
	}

	EAsset(string symbol) {
		symbolName = symbol;
	}

	void SetSymbol(string symbol) {
		symbolName = symbol;
	}

	string GetSymbol() {
		return symbolName;
	}

	JSON::Array *GetMetadata(int accountLeverage) {
		JSON::Array *entries = new JSON::Array();

		addEntry(*entries, "digits", "Price Digits", IntegerToString((int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS)), "integer");
		addEntry(*entries, "contract_size", "Contract Size", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_TRADE_CONTRACT_SIZE), 13, 2), 2), "decimal");
		addEntry(*entries, "spread_type", "Spread Type", getSpreadType(), "string");
		addEntry(*entries, "stops_level", "Stops Level", IntegerToString((int)SymbolInfoInteger(symbolName, SYMBOL_TRADE_STOPS_LEVEL)), "integer");
		addEntry(*entries, "margin_currency", "Margin Currency", SymbolInfoString(symbolName, SYMBOL_CURRENCY_MARGIN), "string");
		addEntry(*entries, "profit_currency", "Profit Currency", SymbolInfoString(symbolName, SYMBOL_CURRENCY_PROFIT), "string");
		addEntry(*entries, "calculation_mode", "Calculation Mode", getCalculationMode(), "string");
		addEntry(*entries, "tick_size", "Tick Size", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_SIZE), 10, 8), 8), "decimal");
		addEntry(*entries, "tick_value", "Tick Value", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_VALUE), 10, 8), 8), "decimal");
		addEntry(*entries, "trade_mode", "Trade Mode", getTradeMode(), "string");
		addEntry(*entries, "execution_mode", "Execution Mode", getExecutionMode(), "string");
		addEntry(*entries, "filling_mode", "Filling Mode", getFillingMode(), "string");
		addEntry(*entries, "minimal_volume", "Min Volume", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN), 10, 4), 4), "decimal");
		addEntry(*entries, "maximal_volume", "Max Volume", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX), 10, 4), 4), "decimal");
		addEntry(*entries, "volume_step", "Volume Step", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_VOLUME_STEP), 10, 4), 4), "decimal");
		addEntry(*entries, "swap_type", "Swap Type", getSwapType(), "string");
		addEntry(*entries, "swap_long", "Swap Long", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_SWAP_LONG), 10, 4), 4), "decimal");
		addEntry(*entries, "swap_short", "Swap Short", DoubleToString(ClampNumeric(SymbolInfoDouble(symbolName, SYMBOL_SWAP_SHORT), 10, 4), 4), "decimal");
		addEntry(*entries, "leverage", "Leverage", IntegerToString(accountLeverage), "integer");

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

	string getSpreadType() {
		long spreadFloat = SymbolInfoInteger(symbolName, SYMBOL_SPREAD_FLOAT);
		return spreadFloat ? "floating" : "fixed";
	}

	string getCalculationMode() {
		ENUM_SYMBOL_CALC_MODE mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbolName, SYMBOL_TRADE_CALC_MODE);

		if (mode == SYMBOL_CALC_MODE_FOREX) {
			return "forex";
		}

		if (mode == SYMBOL_CALC_MODE_FUTURES) {
			return "futures";
		}

		if (mode == SYMBOL_CALC_MODE_CFD) {
			return "cfd";
		}

		if (mode == SYMBOL_CALC_MODE_CFDINDEX) {
			return "cfdindex";
		}

		if (mode == SYMBOL_CALC_MODE_CFDLEVERAGE) {
			return "cfdleverage";
		}

		if (mode == SYMBOL_CALC_MODE_EXCH_STOCKS) {
			return "exchange_stocks";
		}

		if (mode == SYMBOL_CALC_MODE_EXCH_FUTURES) {
			return "exchange_futures";
		}

		return "other";
	}

	string getExecutionMode() {
		ENUM_SYMBOL_TRADE_EXECUTION mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbolName, SYMBOL_TRADE_EXEMODE);

		if (mode == SYMBOL_TRADE_EXECUTION_REQUEST) {
			return "request";
		}

		if (mode == SYMBOL_TRADE_EXECUTION_INSTANT) {
			return "instant";
		}

		if (mode == SYMBOL_TRADE_EXECUTION_MARKET) {
			return "market";
		}

		if (mode == SYMBOL_TRADE_EXECUTION_EXCHANGE) {
			return "exchange";
		}

		return "unknown";
	}

	string getFillingMode() {
		long fillingMode = SymbolInfoInteger(symbolName, SYMBOL_FILLING_MODE);

		if ((fillingMode & SYMBOL_FILLING_FOK) != 0) {
			return "fok";
		}

		if ((fillingMode & SYMBOL_FILLING_IOC) != 0) {
			return "ioc";
		}

		return "return";
	}

	string getSwapType() {
		ENUM_SYMBOL_SWAP_MODE mode = (ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(symbolName, SYMBOL_SWAP_MODE);

		if (mode == SYMBOL_SWAP_MODE_DISABLED) {
			return "disabled";
		}

		if (mode == SYMBOL_SWAP_MODE_POINTS) {
			return "points";
		}

		if (mode == SYMBOL_SWAP_MODE_CURRENCY_SYMBOL) {
			return "currency_symbol";
		}

		if (mode == SYMBOL_SWAP_MODE_CURRENCY_MARGIN) {
			return "currency_margin";
		}

		if (mode == SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT) {
			return "currency_deposit";
		}

		if (mode == SYMBOL_SWAP_MODE_INTEREST_CURRENT) {
			return "interest_current";
		}

		if (mode == SYMBOL_SWAP_MODE_INTEREST_OPEN) {
			return "interest_open";
		}

		if (mode == SYMBOL_SWAP_MODE_REOPEN_CURRENT) {
			return "reopen_current";
		}

		if (mode == SYMBOL_SWAP_MODE_REOPEN_BID) {
			return "reopen_bid";
		}

		return "unknown";
	}

	string getTradeMode() {
		ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbolName, SYMBOL_TRADE_MODE);

		if (mode == SYMBOL_TRADE_MODE_DISABLED) {
			return "disabled";
		}

		if (mode == SYMBOL_TRADE_MODE_LONGONLY) {
			return "longonly";
		}

		if (mode == SYMBOL_TRADE_MODE_SHORTONLY) {
			return "shortonly";
		}

		if (mode == SYMBOL_TRADE_MODE_CLOSEONLY) {
			return "closeonly";
		}

		if (mode == SYMBOL_TRADE_MODE_FULL) {
			return "full";
		}

		return "unknown";
	}
};

#endif
