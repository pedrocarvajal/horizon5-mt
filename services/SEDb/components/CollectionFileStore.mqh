#ifndef __COLLECTION_FILE_STORE_MQH__
#define __COLLECTION_FILE_STORE_MQH__

#include "../structs/SDbDocument.mqh"

#include "../../../constants/COSEDb.mqh"

#include "JsonArraySplitter.mqh"

class CollectionFileStore {
private:
	string filePath;
	int commonFileFlag;
	bool hasLoadError;
	bool isWriteBlocked;
	JsonArraySplitter splitter;

public:
	CollectionFileStore() {
		filePath = "";
		commonFileFlag = 0;
		hasLoadError = false;
		isWriteBlocked = false;
	}

	void Initialize(string collectionFilePath, bool useCommonFiles) {
		filePath = collectionFilePath;
		commonFileFlag = useCommonFiles ? FILE_COMMON : 0;
		hasLoadError = false;
		isWriteBlocked = false;
	}

	bool HasLoadError() {
		return hasLoadError;
	}

	void Quarantine(string reason) {
		hasLoadError = true;
		string quarantinePath = StringFormat("%s.%lld.corrupt", filePath, (long)TimeLocal());

		ResetLastError();

		if (FileMove(filePath, commonFileFlag, quarantinePath, commonFileFlag | FILE_REWRITE)) {
			Print("[ERROR] SEDb: Moved unreadable '", filePath, "' to '", quarantinePath, "' (", reason, ")");
			return;
		}

		isWriteBlocked = true;
		Print("[ERROR] SEDb: Cannot move unreadable '", filePath, "' (", reason, "), error ", GetLastError());
	}

	bool Read(string &documentTexts[]) {
		ArrayResize(documentTexts, 0);

		if (!FileIsExist(filePath, commonFileFlag)) {
			return true;
		}

		ResetLastError();
		int fileHandle = FileOpen(filePath, FILE_READ | FILE_BIN | FILE_SHARE_READ | commonFileFlag);

		if (fileHandle == INVALID_HANDLE) {
			hasLoadError = true;
			isWriteBlocked = true;
			Print("[ERROR] SEDb: Cannot open '", filePath, "', error ", GetLastError());
			return false;
		}

		int fileSize = (int)FileSize(fileHandle);
		uchar fileBytes[];
		ArrayResize(fileBytes, fileSize);
		int bytesRead = (fileSize > 0) ? (int)FileReadArray(fileHandle, fileBytes, 0, fileSize) : 0;
		FileClose(fileHandle);

		if (bytesRead != fileSize) {
			Quarantine("incomplete read");
			return false;
		}

		if (fileSize == 0) {
			return true;
		}

		string content = CharArrayToString(fileBytes, 0, bytesRead, CP_UTF8);

		if (StringLen(content) > 0 && content[0] == 0xFEFF) {
			content = StringSubstr(content, 1);
		}

		if (!splitter.Split(content, documentTexts)) {
			ArrayResize(documentTexts, 0);
			Quarantine("invalid JSON array");
			return false;
		}

		return true;
	}

	bool Write(SDbDocument &documents[], int documentCount) {
		if (isWriteBlocked) {
			Print("[ERROR] SEDb: Refusing to overwrite unreadable '", filePath, "'");
			return false;
		}

		string temporaryPath = filePath + ".tmp";

		ResetLastError();
		int fileHandle = FileOpen(temporaryPath, FILE_WRITE | FILE_BIN | commonFileFlag);

		if (fileHandle == INVALID_HANDLE) {
			Print("[ERROR] SEDb: Cannot write '", temporaryPath, "', error ", GetLastError());
			return false;
		}

		bool isWritten = writeUtf8(fileHandle, "[");
		string chunk = "";
		int chunkDocumentCount = 0;

		for (int i = 0; i < documentCount && isWritten; i++) {
			if (i > 0) {
				chunk += ",";
			}

			chunk += documents[i].text;
			chunkDocumentCount++;

			if (chunkDocumentCount == SEDB_FLUSH_CHUNK_DOCUMENTS) {
				isWritten = writeUtf8(fileHandle, chunk);
				chunk = "";
				chunkDocumentCount = 0;
			}
		}

		if (isWritten) {
			isWritten = writeUtf8(fileHandle, chunk + "]");
		}

		int writeError = GetLastError();
		FileClose(fileHandle);

		if (!isWritten) {
			FileDelete(temporaryPath, commonFileFlag);
			Print("[ERROR] SEDb: Incomplete write of '", temporaryPath, "', error ", writeError);
			return false;
		}

		ResetLastError();

		if (!FileMove(temporaryPath, commonFileFlag, filePath, commonFileFlag | FILE_REWRITE)) {
			Print("[ERROR] SEDb: Cannot replace '", filePath, "', error ", GetLastError());
			FileDelete(temporaryPath, commonFileFlag);
			return false;
		}

		return true;
	}

private:
	bool writeUtf8(int fileHandle, string text) {
		if (text == "") {
			return true;
		}

		uchar textBytes[];
		int byteCount = StringToCharArray(text, textBytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;

		if (byteCount <= 0) {
			return false;
		}

		return FileWriteArray(fileHandle, textBytes, 0, byteCount) == (uint)byteCount;
	}
};

#endif
