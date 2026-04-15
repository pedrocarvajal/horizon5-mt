#ifndef __ORDER_VALIDATOR_MQH__
#define __ORDER_VALIDATOR_MQH__

#include "../../../entities/EAccount.mqh"
#include "../../../entities/EOrder.mqh"

#include "../../../helpers/HIsBuySide.mqh"

#include "../../SELogger/SELogger.mqh"

class OrderValidator {
private:
	SELogger logger;
	string symbol;
	EAccount *account;

public:
	OrderValidator() {
		logger.SetPrefix("OrderBook::Validator");
		account = NULL;
	}

	void Initialize(string orderSymbol, EAccount *tradingAccount) {
		if (CheckPointer(tradingAccount) == POINTER_INVALID) {
			logger.Error(
				LOG_CODE_CONFIG_INVALID_ACCOUNT,
				"configuration invalid | field=account reason='account reference is invalid'"
			);
			return;
		}

		symbol = orderSymbol;
		account = tradingAccount;
	}

	bool ValidateOrder(EOrder &order) {
		if (CheckPointer(account) == POINTER_INVALID) {
			logger.Error(
				LOG_CODE_CONFIG_INVALID_ACCOUNT,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='account reference missing'",
					symbol,
					order.GetId()
			));
			return false;
		}

		bool isBuy = IsBuySide((ENUM_ORDER_TYPE)order.GetSide());

		if (!validateTradeMode(order, isBuy)) {
			return false;
		}

		if (!validateVolume(order)) {
			return false;
		}

		if (!normalizeVolume(order)) {
			return false;
		}

		if (!validatePendingPrice(order)) {
			return false;
		}

		double entryPrice = resolveEntryPrice(order, isBuy);

		if (!validateStopLevels(order, isBuy, entryPrice)) {
			return false;
		}

		if (!validateMargin(order, isBuy, entryPrice)) {
			return false;
		}

		return true;
	}

	bool ValidatePendingCancel(EOrder &order) {
		if (order.GetStatus() != ORDER_STATUS_PENDING) {
			return true;
		}

		long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

		if (freezeLevel <= 0 || order.GetOpenAtPrice() <= 0) {
			return true;
		}

		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
		double freezeDistance = freezeLevel * point;
		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
		double currentPrice = IsBuySide((ENUM_ORDER_TYPE)order.GetSide())
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);
		double distance = MathAbs(currentPrice - order.GetOpenAtPrice());

		if (distance <= freezeDistance) {
			logger.Warning(
				LOG_CODE_VALIDATION_FREEZE_LEVEL,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='price within freeze level' distance=%.*f freeze=%.*f",
					symbol,
					order.GetId(),
					digits,
					distance,
					digits,
					freezeDistance
			));
			return false;
		}

		return true;
	}

private:
	bool validateTradeMode(EOrder &order, bool isBuy) {
		ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);

		if (tradeMode == SYMBOL_TRADE_MODE_DISABLED) {
			logger.Warning(
				LOG_CODE_VALIDATION_TRADE_DISABLED,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='trading disabled'",
					symbol,
					order.GetId()
			));
			return false;
		}

		if (tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY) {
			logger.Warning(
				LOG_CODE_VALIDATION_TRADE_DISABLED,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='close-only mode'",
					symbol,
					order.GetId()
			));
			return false;
		}

		if (tradeMode == SYMBOL_TRADE_MODE_LONGONLY && !isBuy) {
			logger.Warning(
				LOG_CODE_VALIDATION_LONG_ONLY,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='long only'",
					symbol,
					order.GetId()
			));
			return false;
		}

		if (tradeMode == SYMBOL_TRADE_MODE_SHORTONLY && isBuy) {
			logger.Warning(
				LOG_CODE_VALIDATION_SHORT_ONLY,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='short only'",
					symbol,
					order.GetId()
			));
			return false;
		}

		if (!account.IsTradeAllowed()) {
			logger.Warning(
				LOG_CODE_VALIDATION_TRADE_DISABLED,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='trading not allowed on account'",
					symbol,
					order.GetId()
			));
			return false;
		}

		if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
			logger.Warning(
				LOG_CODE_VALIDATION_TRADE_DISABLED,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='autotrading disabled in terminal'",
					symbol,
					order.GetId()
			));
			return false;
		}

		long maxOrders = account.GetMaxOrders();
		if (maxOrders > 0 && (OrdersTotal() + PositionsTotal()) >= (int)maxOrders) {
			logger.Warning(
				LOG_CODE_VALIDATION_ORDER_LIMIT_REACHED,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='account order limit reached' current=%d limit=%d",
					symbol,
					order.GetId(),
					OrdersTotal() + PositionsTotal(),
					(int)maxOrders
			));
			return false;
		}

		return true;
	}

	bool normalizeVolume(EOrder &order) {
		double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

		if (lotStep <= 0) {
			logger.Warning(
				LOG_CODE_VALIDATION_VOLUME_INVALID,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='invalid lot step' lot_step=%.5f",
					symbol,
					order.GetId(),
					lotStep
			));
			return false;
		}

		int volumeDigits = (int)MathRound(-MathLog10(lotStep));
		double normalizedVolume = MathFloor(order.GetVolume() / lotStep) * lotStep;
		normalizedVolume = NormalizeDouble(normalizedVolume, volumeDigits);
		order.SetVolume(normalizedVolume);

		double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
		if (order.GetVolume() > maxLot) {
			logger.Warning(
				LOG_CODE_NONE,
				StringFormat(
					"order volume clamped | symbol=%s order_id=%s lots=%.5f max_lot=%.5f",
					symbol,
					order.GetId(),
					order.GetVolume(),
					maxLot
			));
			order.SetVolume(maxLot);
		}

		return true;
	}

	bool validateVolume(EOrder &order) {
		if (order.GetVolume() <= 0) {
			logger.Warning(
				LOG_CODE_VALIDATION_VOLUME_INVALID,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='volume zero or negative' lots=%.5f",
					symbol,
					order.GetId(),
					order.GetVolume()
			));
			return false;
		}

		double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
		if (order.GetVolume() < minLot) {
			logger.Warning(
				LOG_CODE_VALIDATION_VOLUME_INVALID,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='volume below minimum' lots=%.5f min_lot=%.5f",
					symbol,
					order.GetId(),
					order.GetVolume(),
					minLot
			));
			return false;
		}

		return true;
	}

	bool validatePendingPrice(EOrder &order) {
		if (order.IsMarketOrder()) {
			return true;
		}

		if (order.GetOpenAtPrice() > 0) {
			return true;
		}

		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
		logger.Warning(
			LOG_CODE_VALIDATION_PRICE_INVALID,
			StringFormat(
				"order validation failed | symbol=%s order_id=%s reason='invalid pending price' price=%.*f",
				symbol,
				order.GetId(),
				digits,
				order.GetOpenAtPrice()
		));
		return false;
	}

	double resolveEntryPrice(EOrder &order, bool isBuy) {
		if (!order.IsMarketOrder()) {
			return order.GetOpenAtPrice();
		}

		return isBuy
			? SymbolInfoDouble(symbol, SYMBOL_ASK)
			: SymbolInfoDouble(symbol, SYMBOL_BID);
	}

	bool validateStopLevels(EOrder &order, bool isBuy, double entryPrice) {
		if (order.GetStopLossPrice() > 0) {
			if (!validateStopDistance(order, order.GetStopLossPrice(), entryPrice, isBuy, true)) {
				return false;
			}
		}

		if (order.GetTakeProfitPrice() > 0) {
			if (!validateStopDistance(order, order.GetTakeProfitPrice(), entryPrice, isBuy, false)) {
				return false;
			}
		}

		return true;
	}

	bool validateStopDistance(EOrder &order, double price, double entryPrice, bool isBuy, bool isStopLoss) {
		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
		long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
		double minStopsDistance = stopsLevel * point;

		string sideLabel = isBuy ? "buy" : "sell";
		string priceLabel = isStopLoss ? "stop loss" : "take profit";

		bool wrongDirection = isStopLoss
			? (isBuy ? price >= entryPrice : price <= entryPrice)
			: (isBuy ? price <= entryPrice : price >= entryPrice);

		if (wrongDirection) {
			string expected = isStopLoss
				? (isBuy ? "below" : "above")
				: (isBuy ? "above" : "below");
			logger.Warning(
				LOG_CODE_NONE,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s side=%s reason='%s must be %s entry' price=%.*f entry=%.*f",
					symbol,
					order.GetId(),
					sideLabel,
					priceLabel,
					expected,
					digits,
					price,
					digits,
					entryPrice
			));
			return false;
		}

		if (minStopsDistance > 0 && MathAbs(entryPrice - price) < minStopsDistance) {
			logger.Warning(
				LOG_CODE_VALIDATION_STOP_TOO_CLOSE,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='%s too close to entry' distance=%.*f min_distance=%.*f",
					symbol,
					order.GetId(),
					priceLabel,
					digits,
					MathAbs(entryPrice - price),
					digits,
					minStopsDistance
			));
			return false;
		}

		return true;
	}

	bool validateMargin(EOrder &order, bool isBuy, double entryPrice) {
		double requiredMargin = 0;
		ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

		if (!OrderCalcMargin(orderType, symbol, order.GetVolume(), entryPrice, requiredMargin)) {
			logger.Warning(
				LOG_CODE_VALIDATION_MARGIN_INSUFFICIENT,
				StringFormat(
					"order validation failed | symbol=%s order_id=%s reason='cannot calculate required margin'",
					symbol,
					order.GetId()
			));
			return false;
		}

		double freeMargin = account.GetFreeMargin();

		if (requiredMargin > freeMargin) {
			logger.Warning(
				LOG_CODE_NONE,
				StringFormat(
					"margin insufficient | symbol=%s order_id=%s required=%.2f available=%.2f",
					symbol,
					order.GetId(),
					requiredMargin,
					freeMargin
			));
			return false;
		}

		return true;
	}
};

#endif
