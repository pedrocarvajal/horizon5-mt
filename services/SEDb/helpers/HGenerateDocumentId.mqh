#ifndef __H_GENERATE_DOCUMENT_ID_MQH__
#define __H_GENERATE_DOCUMENT_ID_MQH__

#include "../../../helpers/HFormatUuidVersion4.mqh"

ulong NextDocumentIdRandomValue() {
	static ulong generatorState = 0;

	if (generatorState == 0) {
		generatorState = GetMicrosecondCount() ^ (GetTickCount64() << 21) ^ ((ulong)TimeLocal() << 42);

		if (generatorState == 0) {
			generatorState = 88172645463325252;
		}
	}

	generatorState ^= generatorState >> 12;
	generatorState ^= generatorState << 25;
	generatorState ^= generatorState >> 27;

	return generatorState * 0x2545F4914F6CDD1D;
}

string GenerateDocumentId() {
	uchar randomBytes[];
	ArrayResize(randomBytes, 16);

	for (int block = 0; block < 2; block++) {
		ulong randomValue = NextDocumentIdRandomValue();

		for (int byteIndex = 0; byteIndex < 8; byteIndex++) {
			randomBytes[block * 8 + byteIndex] = (uchar)((randomValue >> (byteIndex * 8)) & 0xFF);
		}
	}

	return FormatUuidVersion4(randomBytes);
}

#endif
