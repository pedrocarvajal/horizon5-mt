#ifndef __H_MATCHES_ORDER_FILTERS_MQH__
#define __H_MATCHES_ORDER_FILTERS_MQH__

bool SEGateway::matchesOrderFilters(EOrder *order, SGatewayEvent &event) {
	if (event.symbol != "" && order.GetSymbol() != event.symbol) {
		return false;
	}

	if (event.side != "" && GetOrderSide(order.GetSide()) != event.side) {
		return false;
	}

	if (event.status != "" && GetOrderStatus(order.GetStatus()) != event.status) {
		return false;
	}

	return true;
}

#endif
