#ifndef __H_GENERATE_UUID_MQH__
#define __H_GENERATE_UUID_MQH__

#include "HFormatUuidVersion4.mqh"

string GenerateUuid() {
	uchar randomBytes[];
	ArrayResize(randomBytes, 16);

	for (int i = 0; i < 16; i++) {
		randomBytes[i] = (uchar)(MathRand() % 256);
	}

	return FormatUuidVersion4(randomBytes);
}

#endif
