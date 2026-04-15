#ifndef __H_HAS_MONITOR_HTTP_FAILED_MQH__
#define __H_HAS_MONITOR_HTTP_FAILED_MQH__

#include "../../../services/SELogger/SELogger.mqh"
#include "../../../services/SERequest/structs/SRequestResponse.mqh"

bool HasMonitorHttpFailed(SRequestResponse &response, SELogger &logger, const string failurePrefix) {
	if (response.status >= 200 && response.status < 300) {
		return false;
	}

	logger.Error(LOG_CODE_REMOTE_HTTP_ERROR, StringFormat(
		"%s status=%d body='%s'",
		failurePrefix,
		response.status,
		response.body
	));

	return true;
}

#endif
