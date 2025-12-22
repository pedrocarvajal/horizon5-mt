#ifndef __ORDER_SERVICE_MQH__
#define __ORDER_SERVICE_MQH__

class Order:
public Trade
{
public:
	bool is_initialized;
	bool is_processed;
	bool is_market_order;

	string id;
	string source;
	string source_custom_id;
	string symbol;
	ulong magic_number;

	ENUM_ORDER_STATUSES status;
	int side;
	ENUM_DEAL_REASON order_close_reason;

	int layer;
	double volume;

	double signal_price;
	double open_at_price;
	double open_price;
	double close_price;

	MqlDateTime signal_at;
	MqlDateTime open_at;
	MqlDateTime close_at;

	double profit_in_dollars;
	double profit_accumulative_in_dollars;

	double main_take_profit_in_points;
	double main_stop_loss_in_points;

	double main_take_profit_at_price;
	double main_stop_loss_at_price;

	SOrderHistory snapshot;
	Logger logger;

public:
	Order(ulong strategy_magic_number = 0, string strategy_symbol = "") {
		is_initialized = false;
		is_processed = false;
		is_market_order = false;
		logger.SetPrefix("Order");

		id = "";
		source_custom_id = "";
		symbol = strategy_symbol;
		magic_number = strategy_magic_number;
		deal_id = 0;
		order_id = 0;
		deal_id = 0;
	}

	Order(const Order& other) {
		is_initialized = other.is_initialized;
		is_processed = other.is_processed;
		is_market_order = other.is_market_order;
		logger.SetPrefix("Order");
		id = other.id;
		source = other.source;
		source_custom_id = other.source_custom_id;
		symbol = other.symbol;
		magic_number = other.magic_number;
		status = other.status;
		side = other.side;
		order_close_reason = other.order_close_reason;
		layer = other.layer;
		volume = other.volume;

		signal_price = other.signal_price;
		open_at_price = other.open_at_price;
		open_price = other.open_price;
		close_price = other.close_price;
		signal_at = other.signal_at;
		open_at = other.open_at;
		close_at = other.close_at;
		profit_in_dollars = other.profit_in_dollars;
		profit_accumulative_in_dollars = other.profit_accumulative_in_dollars;

		main_take_profit_in_points = other.main_take_profit_in_points;
		main_stop_loss_in_points = other.main_stop_loss_in_points;
		main_take_profit_at_price = other.main_take_profit_at_price;
		main_stop_loss_at_price = other.main_stop_loss_at_price;

		snapshot = other.snapshot;

		deal_id = other.deal_id;
		order_id = other.order_id;
		position_id = other.position_id;
	}

	void Snapshot() {
		snapshot.open_time = StructToTime(signal_at);
		snapshot.open_price = signal_price;
		snapshot.open_lot = volume;
		snapshot.order_id = Id();
		snapshot.side = side;
		snapshot.source_custom_id = source_custom_id;
		snapshot.magic_number = magic_number;
		snapshot.strategy_name = source;
		snapshot.strategy_prefix = source;
		snapshot.layer = layer;
		snapshot.status = status;
		snapshot.order_close_reason = order_close_reason;
		snapshot.main_take_profit_in_points = main_take_profit_in_points;
		snapshot.main_stop_loss_in_points = main_stop_loss_in_points;
		snapshot.main_take_profit_at_price = main_take_profit_at_price;
		snapshot.main_stop_loss_at_price = main_stop_loss_at_price;
		snapshot.signal_at = StructToTime(signal_at);
		snapshot.close_time = StructToTime(close_at);
		snapshot.close_price = close_price;
		snapshot.profit_in_dollars = profit_in_dollars;
	}

	void onInit() {
		if (is_initialized) {
			logger.info("[" + Id() + "] Order already initialized");
			return;
		}

		is_initialized = true;
	}

	// Checkers
	void CheckToOpen() {
		if (is_processed)
			return;

		logger.info("[" + Id() + "] " + "Opening order, id=" + Id());
		Open();
	}

	void CheckToClose() {
		Close();
	}

	// Executions
	void Close() {
		if (status == ORDER_STATUS_OPEN) {
			logger.info("[" + Id() + "] " + "Closing open position, position_id=" + IntegerToString(position_id));

			if (!Trade::ClosePosition(position_id)) {
				logger.info("[" + Id() + "] " + "Failed to close open position, ticket=" + IntegerToString(position_id));
				return;
			}

			logger.info("[" + Id() + "] " + "Close order sent to broker, waiting for confirmation...");
			status = ORDER_STATUS_CLOSING;
			return;
		}

		if (status == ORDER_STATUS_PENDING) {
			if (order_id == 0) {
				logger.info("[" + Id() + "] " + "Cannot cancel order: invalid order_id");
				status = ORDER_STATUS_CANCELLED;

				if (CheckPointer(order_persistence) != POINTER_INVALID)
					order_persistence.DeleteOrderJson(source, Id());

				return;
			}

			if (!OrderSelect(order_id)) {
				logger.info("[" + Id() + "] " + "Order no longer exists (order_id=" + IntegerToString(order_id) + "), updating status to cancelled");
				status = ORDER_STATUS_CANCELLED;

				if (CheckPointer(order_persistence) != POINTER_INVALID)
					order_persistence.DeleteOrderJson(source, Id());

				return;
			}

			if (!Trade::CancelOrder(order_id)) {
				logger.info("[" + Id() + "] " + "Failed to cancel pending order, order_id=" + IntegerToString(order_id));
				return;
			}

			logger.info("[" + Id() + "] " + "Cancel order sent to broker, waiting for confirmation...");
			status = ORDER_STATUS_CLOSING;
			return;
		}
	}

	void Open() {
		if (!ValidateMinimumVolume()) {
			status = ORDER_STATUS_CANCELLED;
			is_processed = true;

			logger.info("[" + Id() + "] " + "Order cancelled - Volume does not meet minimum requirements");

			if (CheckPointer(order_persistence) != POINTER_INVALID)
				order_persistence.DeleteOrderJson(source, Id());

			return;
		}

		bool is_buy = (side == ORDER_TYPE_BUY);
		double take_profit = CalculateTakeProfit(open_at_price);
		double stop_loss = CalculateStopLoss(open_at_price);

		MqlTradeResult result = Trade::Open(
			symbol,
			Id(),
			is_buy,
			is_market_order,
			open_at_price,
			volume,
			take_profit,
			stop_loss,
			magic_number
			);

		OnOpen(result);
	}

	// Events
	void OnClose(
		const MqlDateTime &time,
		double price,
		double profits,
		ENUM_DEAL_REASON reason
		) {
		close_at = time;
		close_price = price;
		profit_in_dollars = profits;
		profit_accumulative_in_dollars += profits;
		status = ORDER_STATUS_CLOSED;

		if (profits == 0.0 && price == 0.0) {
			status = ORDER_STATUS_CANCELLED;
			logger.info("[" + Id() + "] " + "Order cancelled");
		}

		order_close_reason = reason;
		Snapshot();

		if (CheckPointer(order_history_reporter) != POINTER_INVALID) {
			order_history_reporter.AddOrderSnapshot(snapshot);
			logger.info("[" + Id() + "] " + "Order snapshot added to report");
		}

		if (reason == DEAL_REASON_TP)
			logger.info("[" + Id() + "] " + "Order closed by Take Profit");

		if (reason == DEAL_REASON_EXPERT)
			logger.info("[" + Id() + "] " + "Order closed by Expert");

		if (reason == DEAL_REASON_CLIENT)
			logger.info("[" + Id() + "] " + "Order closed by Client");

		if (reason == DEAL_REASON_MOBILE)
			logger.info("[" + Id() + "] " + "Order closed by Mobile");

		if (reason == DEAL_REASON_WEB)
			logger.info("[" + Id() + "] " + "Order closed by Web");

		if (reason == DEAL_REASON_SL)
			logger.info("[" + Id() + "] " + "Order closed by Stop Loss");

		if (status == ORDER_STATUS_CLOSED) {
			if (CheckPointer(order_persistence) != POINTER_INVALID)
				order_persistence.DeleteOrderJson(source, Id());
		}
	}

	void OnOpen(const MqlTradeResult &result) {
		if (result.retcode != 0 && result.retcode != 10009 && result.retcode != 10010) {
			logger.info("[" + Id() + "] " + "Error opening order: (retcode) " + IntegerToString(result.retcode));

			status = ORDER_STATUS_CANCELLED;
			is_processed = true;

			if (CheckPointer(order_persistence) != POINTER_INVALID)
				order_persistence.DeleteOrderJson(source, Id());

			return;
		}

		bool was_pending = (status == ORDER_STATUS_PENDING);
		is_processed = true;
		open_at = dtime.Now();
		open_price = result.price;
		deal_id = result.deal;
		order_id = result.order;

		if (deal_id > 0) {
			HistoryDealSelect(deal_id);
			position_id = HistoryDealGetInteger(deal_id, DEAL_POSITION_ID);
		}

		if (deal_id == 0) {
			status = ORDER_STATUS_PENDING;
			logger.info("[" + Id() + "] " + "Order opened as pending, order_id=" + IntegerToString(order_id));
		} else {
			if (was_pending)
				logger.info("[" + Id() + "] " + "Pending order has opened, deal_id=" + IntegerToString(deal_id) + ", position_id=" + IntegerToString(position_id));
			else
				logger.info("[" + Id() + "] " + "Order opened immediately, deal_id=" + IntegerToString(deal_id) + ", position_id=" + IntegerToString(position_id));

			status = ORDER_STATUS_OPEN;
		}

		Snapshot();

		if (CheckPointer(order_persistence) != POINTER_INVALID)
			order_persistence.SaveOrderToJson(this);
	}

	// Property helpers
	void SetId(string new_id) {
		id = new_id;
	}

	string Id() {
		if (id == "")
			RefreshId();

		return id;
	}

	void RefreshId() {
		id = source + "_" + IntegerToString(layer) + "_" + generateUUID();
	}

	double CalculateTakeProfit(double price) {
		if (main_take_profit_at_price > 0)
			return main_take_profit_at_price;

		if (main_take_profit_in_points == 0)
			return 0;

		return (side == ORDER_TYPE_BUY)
			? price + (main_take_profit_in_points * SymbolInfoDouble(symbol, SYMBOL_POINT))
			: price - (main_take_profit_in_points * SymbolInfoDouble(symbol, SYMBOL_POINT));
	}

	double CalculateStopLoss(double price) {
		if (main_stop_loss_at_price > 0)
			return main_stop_loss_at_price;

		if (main_stop_loss_in_points == 0)
			return 0;

		return (side == ORDER_TYPE_BUY)
			? price - (main_stop_loss_in_points * SymbolInfoDouble(symbol, SYMBOL_POINT))
			: price + (main_stop_loss_in_points * SymbolInfoDouble(symbol, SYMBOL_POINT));
	}

	bool ValidateMinimumVolume() {
		double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
		double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		if (volume <= 0) {
			logger.info("[" + Id() + "] " + "Validation failed - Volume is zero or negative: " + DoubleToString(volume, 5));
			return false;
		}

		if (volume < min_lot) {
			logger.info("[" + Id() + "] " + "Validation failed - Volume " + DoubleToString(volume, 5) + " is below minimum lot size: " + DoubleToString(min_lot, 5));
			return false;
		}

		if (volume > max_lot) {
			logger.info("[" + Id() + "] " + "Validation failed - Volume " + DoubleToString(volume, 5) + " exceeds maximum lot size: " + DoubleToString(max_lot, 5));
			return false;
		}

		double normalized_volume = MathFloor(volume / lot_step) * lot_step;
		if (normalized_volume < min_lot) {
			logger.info("[" + Id() + "] " + "Validation failed - Normalized volume " + DoubleToString(normalized_volume, 5) + " is below minimum after lot step adjustment");
			return false;
		}

		return true;
	}

	void onDeinit() {
		id = "";
		source = "";
		source_custom_id = "";
		status = ORDER_STATUS_CLOSED;
		is_initialized = false;
		is_processed = false;
	}
};

#endif
