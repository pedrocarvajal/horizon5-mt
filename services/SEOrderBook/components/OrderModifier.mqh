#ifndef __ORDER_MODIFIER_MQH__
#define __ORDER_MODIFIER_MQH__

#include "../../../adapters/ATrade.mqh"

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../helpers/HTradeRetcodeToLogCode.mqh"

#include "../../SELogger/SELogger.mqh"

class OrderModifier {
private:
	SELogger logger;
	string symbol;
	ulong magicNumber;
	ATrade *trade;

public:
	OrderModifier() {
		logger.SetPrefix("OrderBook::Modifier");
		trade = NULL;
		magicNumber = 0;
	}

	void Initialize(string orderSymbol, ulong orderMagicNumber, ATrade *tradeRef) {
		symbol = orderSymbol;
		magicNumber = orderMagicNumber;
		trade = tradeRef;
	}

	bool ModifyStopLoss(EOrder &order, double newStopLossPrice) {
		return ModifyStopLossAndTakeProfit(order, newStopLossPrice, 0);
	}

	bool ModifyTakeProfit(EOrder &order, double newTakeProfitPrice) {
		return ModifyStopLossAndTakeProfit(order, 0, newTakeProfitPrice);
	}

	bool ModifyStopLossAndTakeProfit(EOrder &order, double newStopLossPrice, double newTakeProfitPrice) {
		bool hasStopLoss = (newStopLossPrice > 0);
		bool hasTakeProfit = (newTakeProfitPrice > 0);

		if (!hasStopLoss && !hasTakeProfit) {
			return false;
		}

		if (order.GetStatus() != ORDER_STATUS_OPEN) {
			logger.Warning(LOG_CODE_ORDER_MODIFY_REJECTED, StringFormat(
				"order modify rejected | symbol=%s order_id=%s status=%d change=%s reason='order not open'",
				symbol,
				order.GetId(),
				order.GetStatus(),
				describeChange(hasStopLoss, hasTakeProfit)
			));
			return false;
		}

		trade.SetPositionId(order.GetPositionId());

		STradeResult result = trade.ModifyStopLossAndTakeProfit(newStopLossPrice, newTakeProfitPrice, magicNumber);

		if (result.severity != TRADE_SEVERITY_SUCCESS) {
			logger.Error(GetTradeRetcodeLogCode(result.retcode), StringFormat(
				"order modify failed | symbol=%s order_id=%s position_id=%llu change=%s error=%d reason='%s'",
				symbol,
				order.GetId(),
				order.GetPositionId(),
				describeChange(hasStopLoss, hasTakeProfit),
				result.retcode,
				ATrade::DescribeRetcode(result.retcode)
			));
			return false;
		}

		int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

		if (hasStopLoss && hasTakeProfit) {
			logger.Info(LOG_CODE_ORDER_MODIFIED, StringFormat(
				"order sl/tp modified | symbol=%s order_id=%s position_id=%llu sl=%.*f tp=%.*f",
				symbol,
				order.GetId(),
				order.GetPositionId(),
				digits,
				newStopLossPrice,
				digits,
				newTakeProfitPrice
			));
		} else if (hasStopLoss) {
			logger.Info(LOG_CODE_ORDER_MODIFIED, StringFormat(
				"order sl modified | symbol=%s order_id=%s position_id=%llu sl=%.*f",
				symbol,
				order.GetId(),
				order.GetPositionId(),
				digits,
				newStopLossPrice
			));
		} else {
			logger.Info(LOG_CODE_ORDER_MODIFIED, StringFormat(
				"order tp modified | symbol=%s order_id=%s position_id=%llu tp=%.*f",
				symbol,
				order.GetId(),
				order.GetPositionId(),
				digits,
				newTakeProfitPrice
			));
		}

		if (hasStopLoss) {
			order.SetStopLossPrice(newStopLossPrice);
		}

		if (hasTakeProfit) {
			order.SetTakeProfitPrice(newTakeProfitPrice);
		}

		return true;
	}

private:
	string describeChange(bool hasStopLoss, bool hasTakeProfit) {
		if (hasStopLoss && hasTakeProfit) {
			return "SL/TP";
		}

		return hasStopLoss ? "stop loss" : "take profit";
	}
};

#endif
