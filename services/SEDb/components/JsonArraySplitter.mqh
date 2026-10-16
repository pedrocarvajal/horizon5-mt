#ifndef __JSON_ARRAY_SPLITTER_MQH__
#define __JSON_ARRAY_SPLITTER_MQH__

#include "../../../constants/COSEDb.mqh"

class JsonArraySplitter {
private:
	int contentLength;
	ushort expectedClosers[];

public:
	JsonArraySplitter() {
		contentLength = 0;
	}

	bool Split(string &content, string &objectTexts[]) {
		ArrayResize(objectTexts, 0);
		contentLength = StringLen(content);

		int position = skipWhitespace(content, 0);

		if (position >= contentLength || content[position] != '[') {
			return false;
		}

		position = skipWhitespace(content, position + 1);

		if (position < contentLength && content[position] == ']') {
			return skipWhitespace(content, position + 1) == contentLength;
		}

		int objectCount = 0;

		while (position < contentLength) {
			int valueEnd = findValueEnd(content, position);

			if (valueEnd == -1) {
				return false;
			}

			if (content[position] == '{') {
				ArrayResize(objectTexts, objectCount + 1, MathMax(objectCount, SEDB_MINIMUM_DOCUMENT_RESERVE));
				objectTexts[objectCount] = StringSubstr(content, position, valueEnd - position);
				objectCount++;
			}

			position = skipWhitespace(content, valueEnd);

			if (position >= contentLength) {
				return false;
			}

			ushort separator = content[position];
			position++;

			if (separator == ']') {
				return skipWhitespace(content, position) == contentLength;
			}

			if (separator != ',') {
				return false;
			}

			position = skipWhitespace(content, position);
		}

		return false;
	}

private:
	int findContainerEnd(string &content, int start) {
		int depth = 0;
		int position = start;

		while (position < contentLength) {
			ushort character = content[position];

			if (character == '"') {
				position = findStringEnd(content, position);

				if (position == -1) {
					return -1;
				}

				continue;
			}

			if (character == '{' || character == '[') {
				ArrayResize(expectedClosers, depth + 1, SEDB_MINIMUM_DOCUMENT_RESERVE);
				expectedClosers[depth] = (character == '{') ? '}' : ']';
				depth++;
			} else if (character == '}' || character == ']') {
				if (depth == 0 || expectedClosers[depth - 1] != character) {
					return -1;
				}

				depth--;

				if (depth == 0) {
					return position + 1;
				}
			}

			position++;
		}

		return -1;
	}

	int findScalarEnd(string &content, int start) {
		int position = start;

		while (position < contentLength) {
			ushort character = content[position];

			if (character == ',' || character == ']' || character == '}' || isWhitespace(character)) {
				break;
			}

			position++;
		}

		return position > start ? position : -1;
	}

	int findStringEnd(string &content, int start) {
		int position = start + 1;

		while (position < contentLength) {
			ushort character = content[position];

			if (character == '\\') {
				position += 2;
				continue;
			}

			if (character == '"') {
				return position + 1;
			}

			position++;
		}

		return -1;
	}

	int findValueEnd(string &content, int start) {
		ushort firstCharacter = content[start];

		if (firstCharacter == '"') {
			return findStringEnd(content, start);
		}

		if (firstCharacter == '{' || firstCharacter == '[') {
			return findContainerEnd(content, start);
		}

		return findScalarEnd(content, start);
	}

	bool isWhitespace(ushort character) {
		return character == ' ' || character == '\t' || character == '\n' || character == '\r';
	}

	int skipWhitespace(string &content, int position) {
		while (position < contentLength && isWhitespace(content[position])) {
			position++;
		}

		return position;
	}
};

#endif
