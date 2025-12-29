#ifndef __H_STRING_TO_NUMBER_MQH__
#define __H_STRING_TO_NUMBER_MQH__

ulong StringToNumber(string text) {
	ulong hash = 5381;
	int length = StringLen(text);

	for (int i = 0; i < length; i++) {
		ushort character = StringGetCharacter(text, i);
		hash = ((hash << 5) + hash) + character;
	}

	return hash % 1000000000;
}

#endif
