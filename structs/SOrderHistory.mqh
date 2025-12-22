#ifndef __SORDER_HISTORY_MQH__
#define __SORDER_HISTORY_MQH__

struct SOrderHistory {
	string order_id;
	string strategy_name;
	string strategy_prefix;
	string source_custom_id;
	ulong magic_number;
	int layer;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON order_close_reason;

	double main_take_profit_in_points;
	double main_stop_loss_in_points;
	double main_take_profit_at_price;
	double main_stop_loss_at_price;

	datetime signal_at;
	datetime open_time;
	double open_price;
	double open_lot;

	datetime close_time;
	double close_price;

	double profit_in_dollars;
};

#endif
