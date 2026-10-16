#ifndef __SE_DB_COLLECTION_MQH__
#define __SE_DB_COLLECTION_MQH__

#include "../../libraries/Json/index.mqh"

#include "components/CollectionFileStore.mqh"

#include "helpers/HGenerateDocumentId.mqh"

#include "structs/SDbDocument.mqh"

#include "../../constants/COSEDb.mqh"

class SEDbCollection {
private:
	string name;
	bool autoFlush;
	int documentCount;
	SDbDocument documents[];
	CollectionFileStore fileStore;

public:
	SEDbCollection() {
		name = "";
		autoFlush = true;
		documentCount = 0;
	}

	void Initialize(string collectionName, string databasePath, bool useCommonFiles) {
		name = collectionName;
		autoFlush = true;
		documentCount = 0;
		ArrayResize(documents, 0);
		fileStore.Initialize(StringFormat("%s\\%s.json", databasePath, collectionName), useCommonFiles);

		loadDocuments();
	}

	string GetName() {
		return name;
	}

	bool HasLoadError() {
		return fileStore.HasLoadError();
	}

	void SetAutoFlush(bool enabled) {
		autoFlush = enabled;
	}

	bool Flush() {
		return fileStore.Write(documents, documentCount);
	}

	bool InsertOne(JSON::Object *document) {
		if (document == NULL) {
			return false;
		}

		if (!document.isSerializable()) {
			Print("[ERROR] SEDb: Rejected document with a non-finite number in collection '", name, "'");
			return false;
		}

		string documentText = document.toString();
		string documentId = readDocumentId(document);

		if (documentId == "") {
			documentId = GenerateDocumentId();
			documentText = appendDocumentId(documentText, documentId);
		}

		appendDocument(documentText, documentId);

		if (autoFlush) {
			Flush();
		}

		return true;
	}

	JSON::Object *FindOne(string key, string value) {
		int index = findDocumentIndex(key, value);

		if (index == -1) {
			return NULL;
		}

		return parseDocument(index);
	}

	int FindAll(JSON::Object *&results[]) {
		ArrayResize(results, documentCount);

		for (int i = 0; i < documentCount; i++) {
			results[i] = parseDocument(i);
		}

		return documentCount;
	}

	bool UpdateOne(string key, string value, JSON::Object *newData) {
		if (newData == NULL) {
			return false;
		}

		if (!newData.isSerializable()) {
			Print("[ERROR] SEDb: Rejected update with a non-finite number in collection '", name, "'");
			return false;
		}

		int index = findDocumentIndex(key, value);

		if (index == -1) {
			return false;
		}

		string documentText = documents[index].text;
		JSON::Object document(documentText);

		if (!isParsedDocument(document, documents[index].text)) {
			Print("[ERROR] SEDb: Cannot parse document in collection '", name, "' for update");
			return false;
		}

		string patchKeys[];
		newData.getKeysToArray(patchKeys);

		for (int i = 0; i < ArraySize(patchKeys); i++) {
			copyProperty(GetPointer(document), newData, patchKeys[i]);
		}

		documents[index].text = document.toString();
		documents[index].id = readDocumentId(GetPointer(document));

		if (autoFlush) {
			Flush();
		}

		return true;
	}

	bool UpsertOne(string key, string value, JSON::Object *document) {
		if (findDocumentIndex(key, value) == -1) {
			return InsertOne(document);
		}

		return UpdateOne(key, value, document);
	}

	bool DeleteOne(string key, string value) {
		int index = findDocumentIndex(key, value);

		if (index == -1) {
			return false;
		}

		int lastIndex = documentCount - 1;

		if (index != lastIndex) {
			documents[index] = documents[lastIndex];
		}

		documents[lastIndex].text = "";
		documents[lastIndex].id = "";
		documentCount--;

		if (autoFlush) {
			Flush();
		}

		return true;
	}

	int Count() {
		return documentCount;
	}

private:
	void appendDocument(string documentText, string documentId) {
		if (documentCount >= ArraySize(documents)) {
			ArrayResize(documents, documentCount + 1, MathMax(documentCount, SEDB_MINIMUM_DOCUMENT_RESERVE));
		}

		documents[documentCount].text = documentText;
		documents[documentCount].id = documentId;
		documentCount++;
	}

	string appendDocumentId(string documentText, string documentId) {
		string idProperty = "\"_id\": \"" + documentId + "\"";

		if (isEmptyObjectText(documentText)) {
			return "{" + idProperty + "}";
		}

		return StringSubstr(documentText, 0, StringLen(documentText) - 1) + "," + idProperty + "}";
	}

	JSON::Array *cloneArray(JSON::Array *source) {
		JSON::Array *clone = new JSON::Array();

		for (int i = 0; i < source.getLength(); i++) {
			if (source.isString(i)) {
				clone.add(source.getString(i));
			} else if (source.isNumber(i)) {
				clone.add(source.getNumber(i));
			} else if (source.isBoolean(i)) {
				clone.add(source.getBoolean(i));
			} else if (source.isObject(i)) {
				clone.add(cloneObject(source.getObject(i)));
			} else if (source.isArray(i)) {
				clone.add(cloneArray(source.getArray(i)));
			}
		}

		return clone;
	}

	JSON::Object *cloneObject(JSON::Object *source) {
		JSON::Object *clone = new JSON::Object();
		string keys[];
		source.getKeysToArray(keys);

		for (int i = 0; i < ArraySize(keys); i++) {
			copyProperty(clone, source, keys[i]);
		}

		return clone;
	}

	void copyProperty(JSON::Object *target, JSON::Object *source, string key) {
		if (source.isString(key)) {
			target.setProperty(key, source.getString(key));
		} else if (source.isNumber(key)) {
			target.setProperty(key, source.getNumber(key));
		} else if (source.isBoolean(key)) {
			target.setProperty(key, source.getBoolean(key));
		} else if (source.isObject(key)) {
			target.setProperty(key, cloneObject(source.getObject(key)));
		} else if (source.isArray(key)) {
			target.setProperty(key, cloneArray(source.getArray(key)));
		}
	}

	int findDocumentIndex(string key, string value) {
		if (key == "_id") {
			if (value == "") {
				return -1;
			}

			for (int i = documentCount - 1; i >= 0; i--) {
				if (documents[i].id == value) {
					return i;
				}
			}

			return -1;
		}

		for (int i = 0; i < documentCount; i++) {
			string documentText = documents[i].text;
			JSON::Object document(documentText);

			if (document.isString(key) && document.getString(key) == value) {
				return i;
			}
		}

		return -1;
	}

	bool isEmptyObjectText(string documentText) {
		string compactText = documentText;
		StringReplace(compactText, " ", "");
		StringReplace(compactText, "\t", "");
		StringReplace(compactText, "\r", "");
		StringReplace(compactText, "\n", "");
		return compactText == "{}";
	}

	bool isParsedDocument(JSON::Object &document, string documentText) {
		string keys[];
		document.getKeysToArray(keys);
		return ArraySize(keys) > 0 || isEmptyObjectText(documentText);
	}

	void loadDocuments() {
		string documentTexts[];

		if (!fileStore.Read(documentTexts)) {
			return;
		}

		for (int i = 0; i < ArraySize(documentTexts); i++) {
			string documentText = documentTexts[i];
			JSON::Object document(documentText);

			if (!isParsedDocument(document, documentText)) {
				documentCount = 0;
				ArrayResize(documents, 0);
				fileStore.Quarantine(StringFormat("unparseable document at index %d", i));
				return;
			}

			appendDocument(documentText, readDocumentId(GetPointer(document)));
		}
	}

	JSON::Object *parseDocument(int index) {
		string documentText = documents[index].text;
		return new JSON::Object(documentText);
	}

	string readDocumentId(JSON::Object *document) {
		return document.isString("_id") ? document.getString("_id") : "";
	}
};

#endif
