#ifndef __H_FORMAT_UUID_VERSION4_MQH__
#define __H_FORMAT_UUID_VERSION4_MQH__

string FormatUuidVersion4(uchar &randomBytes[]) {
	randomBytes[6] = (uchar)((randomBytes[6] & 0x0F) | 0x40);
	randomBytes[8] = (uchar)((randomBytes[8] & 0x3F) | 0x80);

	string hexadecimalDigits = "";

	for (int i = 0; i < 16; i++) {
		hexadecimalDigits += StringFormat("%02x", randomBytes[i]);
	}

	return StringFormat(
		"%s-%s-%s-%s-%s",
		StringSubstr(hexadecimalDigits, 0, 8),
		StringSubstr(hexadecimalDigits, 8, 4),
		StringSubstr(hexadecimalDigits, 12, 4),
		StringSubstr(hexadecimalDigits, 16, 4),
		StringSubstr(hexadecimalDigits, 20, 12)
	);
}

#endif
