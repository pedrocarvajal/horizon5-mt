#ifndef __SS_QUALITY_RESULT_MQH__
#define __SS_QUALITY_RESULT_MQH__

struct SSQualityResult {
	double quality;
	string reason;

	SSQualityResult(const SSQualityResult &other) {
		quality = other.quality;
		reason = other.reason;
	}

	SSQualityResult() {
		quality = 0.0;
		reason = "";
	}
};

#endif
