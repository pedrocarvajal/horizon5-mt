#ifndef __ORDER_EXISTENCE_VALIDATOR_MQH__
#define __ORDER_EXISTENCE_VALIDATOR_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

#include "../../../helpers/HIsLiveTrading.mqh"

class OrderExistenceValidator {
public:
	bool Validate(EOrder &order) {
		if (!IsLiveTrading()) {
			return true;
		}

		if (order.GetStatus() == ORDER_STATUS_CLOSED || order.GetStatus() == ORDER_STATUS_CANCELLED) {
			return true;
		}

		if (order.GetStatus() == ORDER_STATUS_PENDING && order.GetOrderId() > 0) {
			return OrderSelect(order.GetOrderId());
		}

		if (order.GetStatus() == ORDER_STATUS_OPEN && order.GetPositionId() > 0) {
			return PositionSelectByTicket(order.GetPositionId());
		}

		return false;
	}
};

#endif
