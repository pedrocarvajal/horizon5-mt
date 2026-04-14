#ifndef __H_CALCULATE_FLOATING_PNL_MQH__
#define __H_CALCULATE_FLOATING_PNL_MQH__

#include "../../../entities/EOrder.mqh"

#include "../../../enums/EOrderStatuses.mqh"

double CalculateFloatingPnl(EOrder &strategyOrders[]) {
	double floatingPnl = 0.0;

	for (int i = 0; i < ArraySize(strategyOrders); i++) {
		if (strategyOrders[i].GetStatus() == ORDER_STATUS_OPEN) {
			floatingPnl += strategyOrders[i].GetFloatingPnL();
		}
	}

	return floatingPnl;
}

#endif
