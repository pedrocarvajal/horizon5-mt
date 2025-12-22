#ifndef __SQUALITY_RESULT_MQH__
#define __SQUALITY_RESULT_MQH__

struct SQualityResult {
	double quality;
	string reason;

	SQualityResult(const SQualityResult &other) {
		quality = other.quality;
		reason = other.reason;
	}

	SQualityResult() {
		quality = 0.0;
		reason = "";
	}
};

#endif
