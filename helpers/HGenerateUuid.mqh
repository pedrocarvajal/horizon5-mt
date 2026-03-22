#ifndef __H_GENERATE_UUID_MQH__
#define __H_GENERATE_UUID_MQH__

string GenerateUuid() {
	uchar randomBytes[];
	ArrayResize(randomBytes, 16);

	for (int i = 0; i < 16; i++) {
		randomBytes[i] = (uchar)(MathRand() % 256);
	}

	randomBytes[6] = (uchar)((randomBytes[6] & 0x0F) | 0x40);
	randomBytes[8] = (uchar)((randomBytes[8] & 0x3F) | 0x80);

	string hex = "";

	for (int i = 0; i < 16; i++) {
		hex += StringFormat("%02x", randomBytes[i]);
	}

	return StringFormat(
		"%s-%s-%s-%s-%s",
		StringSubstr(hex, 0, 8),
		StringSubstr(hex, 8, 4),
		StringSubstr(hex, 12, 4),
		StringSubstr(hex, 16, 4),
		StringSubstr(hex, 20, 12)
	);
}

#endif
