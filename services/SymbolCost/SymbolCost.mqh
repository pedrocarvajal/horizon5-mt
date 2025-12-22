#ifndef __SYMBOL_COST_SERVICE_MQH__
#define __SYMBOL_COST_SERVICE_MQH__

#include "structs/SymbolConfig.mqh"

class SymbolCost
{
private:
	string symbol;
	SSymbolConfig symbol_configs[];
	SSymbolConfig default_config;

	void InitializeConfigurations() {
		default_config.symbol = "DEFAULT";
		default_config.commission_per_lot = 7.0;
		default_config.commission_type = COMMISSION_TYPE_USD_PER_LOT;

		ArrayResize(symbol_configs, 5);

		symbol_configs[0].symbol = "EURUSD";
		symbol_configs[0].commission_per_lot = 2.5;
		symbol_configs[0].commission_type = COMMISSION_TYPE_USD_PER_LOT;

		symbol_configs[1].symbol = "XAUUSD";
		symbol_configs[1].commission_per_lot = 0.0025;
		symbol_configs[1].commission_type = COMMISSION_TYPE_PERCENTAGE;

		symbol_configs[2].symbol = "XAGUSD";
		symbol_configs[2].commission_per_lot = 0.0025;
		symbol_configs[2].commission_type = COMMISSION_TYPE_PERCENTAGE;

		symbol_configs[3].symbol = "SP500";
		symbol_configs[3].commission_per_lot = 0.275;
		symbol_configs[3].commission_type = COMMISSION_TYPE_POINTS_PER_LOT;

		symbol_configs[4].symbol = "XTIUSD";
		symbol_configs[4].commission_per_lot = 0.0025;
		symbol_configs[4].commission_type = COMMISSION_TYPE_PERCENTAGE;
	}

	SSymbolConfig GetSymbolConfig(string check_symbol) {
		for (int i = 0; i < ArraySize(symbol_configs); i++)
			if (symbol_configs[i].symbol == check_symbol)
				return symbol_configs[i];

		return default_config;
	}

public:
	SymbolCost(string _symbol) {
		symbol = _symbol;
		InitializeConfigurations();
	}

	double GetSpreadInPoints() {
		long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
		return (double)spread_points;
	}

	double GetSpreadCost() {
		double spread_points = GetSpreadInPoints();
		double point_value = SymbolInfoDouble(symbol, SYMBOL_POINT);
		double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
		double spread_cost_per_lot = spread_points * point_value * contract_size;

		return spread_cost_per_lot;
	}

	double GetCommissionPerLot() {
		SSymbolConfig config = GetSymbolConfig(symbol);

		if (config.commission_type == COMMISSION_TYPE_USD_PER_LOT)
			return config.commission_per_lot;

		if (config.commission_type == COMMISSION_TYPE_POINTS_PER_LOT) {
			double point_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
			double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
			double point_size = SymbolInfoDouble(symbol, SYMBOL_POINT);
			double commission_in_usd = config.commission_per_lot * (point_size / tick_size) * point_value;

			return commission_in_usd;
		}

		if (config.commission_type == COMMISSION_TYPE_PERCENTAGE)
			return 0.0;

		return config.commission_per_lot;
	}

	double GetCommissionCost(double volume, double price = 0.0) {
		SSymbolConfig config = GetSymbolConfig(symbol);

		if (config.commission_type == COMMISSION_TYPE_USD_PER_LOT || config.commission_type == COMMISSION_TYPE_POINTS_PER_LOT)
			return GetCommissionPerLot() * volume;

		if (config.commission_type == COMMISSION_TYPE_PERCENTAGE) {
			if (price <= 0.0)
				price = SymbolInfoDouble(symbol, SYMBOL_BID);

			double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
			double trade_value = volume * contract_size * price;
			double commission_cost = trade_value * (config.commission_per_lot / 100.0);

			return commission_cost;
		}

		return GetCommissionPerLot() * volume;
	}

	double GetPointValue(string target_symbol = "") {
		string symbol_to_check = (target_symbol == "") ? symbol : target_symbol;

		if (symbol_to_check == "XAUUSD")
			return 80.0;
		else if (symbol_to_check == "XAGUSD")
			return 20.0;
		else if (symbol_to_check == "SP500")
			return 6.0;
		else if (symbol_to_check == "XTIUSD")
			return 20.0;
		else if (symbol_to_check == "EURUSD")
			return 10.0;

		return 10.0;
	}
};

#endif
