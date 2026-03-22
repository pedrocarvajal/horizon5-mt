#ifndef __H_GENERATE_DETERMINISTIC_UUID_MQH__
#define __H_GENERATE_DETERMINISTIC_UUID_MQH__

string GenerateDeterministicUuid(string seed) {
	uchar seedBytes[];
	StringToCharArray(seed, seedBytes);
	int seedLength = ArraySize(seedBytes);

	uchar hash[];
	ArrayResize(hash, 16);
	ArrayInitialize(hash, 0);

	for (int i = 0; i < seedLength; i++) {
		hash[i % 16] ^= seedBytes[i];
		hash[i % 16] = (uchar)((hash[i % 16] * 31 + seedBytes[i]) & 0xFF);

		int next = (i + 1) % 16;
		hash[next] = (uchar)((hash[next] + hash[i % 16] * 7) & 0xFF);
	}

	for (int round = 0; round < 4; round++) {
		for (int i = 0; i < 16; i++) {
			int prev = (i + 15) % 16;
			hash[i] = (uchar)((hash[i] ^ (hash[prev] * 13 + round)) & 0xFF);
		}
	}

	hash[6] = (uchar)((hash[6] & 0x0F) | 0x50);
	hash[8] = (uchar)((hash[8] & 0x3F) | 0x80);

	string hex = "";

	for (int i = 0; i < 16; i++) {
		hex += StringFormat("%02x", hash[i]);
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
