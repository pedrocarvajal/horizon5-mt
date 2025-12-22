#ifndef __SYMBOL_CONFIG_STRUCT_MQH__
#define __SYMBOL_CONFIG_STRUCT_MQH__

enum ENUM_COMMISSION_TYPE {
	COMMISSION_TYPE_USD_PER_LOT,
	COMMISSION_TYPE_POINTS_PER_LOT,
	COMMISSION_TYPE_PERCENTAGE
};

struct SSymbolConfig {
	string symbol;
	double commission_per_lot;
	ENUM_COMMISSION_TYPE commission_type;
};

#endif
