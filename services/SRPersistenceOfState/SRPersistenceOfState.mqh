#ifndef __SR_PERSISTENCE_OF_STATE_MQH__
#define __SR_PERSISTENCE_OF_STATE_MQH__

#include "../../helpers/HIsLiveTrading.mqh"

#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"

class SRPersistenceOfState {
private:
	SELogger logger;
	SEDb database;
	SEDbCollection *stateCollection;
	JSON::Object *stateDocument;

	void ensureDocument() {
		if (stateDocument != NULL) {
			return;
		}

		stateDocument = stateCollection.FindOne("_id", "state");

		if (stateDocument == NULL) {
			stateDocument = new JSON::Object();
			stateDocument.setProperty("_id", "state");
			stateCollection.InsertOne(stateDocument);
			stateDocument = stateCollection.FindOne("_id", "state");
		}
	}

	void flush() {
		if (stateDocument == NULL) {
			return;
		}

		stateCollection.UpdateOne("_id", "state", stateDocument);
	}

public:
	SRPersistenceOfState() {
		logger.SetPrefix("StatePersistence");
		stateCollection = NULL;
		stateDocument = NULL;
	}

	void Initialize(string symbolName, string strategyPrefix) {
		string basePath = StringFormat("Live/%s/%s", symbolName, strategyPrefix);
		database.Initialize(basePath, true);
		stateCollection = database.Collection("state");
	}

	bool Load() {
		if (!IsLiveTrading()) {
			return true;
		}

		if (stateCollection == NULL) {
			return false;
		}

		stateDocument = stateCollection.FindOne("_id", "state");
		return true;
	}

	void SetDouble(string key, double value) {
		if (!IsLiveTrading() || stateCollection == NULL) {
			return;
		}

		ensureDocument();
		stateDocument.setProperty(key, value);
		flush();
	}

	void GetDouble(string key, double &value, double defaultValue) {
		if (stateDocument != NULL && stateDocument.hasValue(key)) {
			value = stateDocument.getNumber(key);
			return;
		}

		value = defaultValue;
	}

	void SetInt(string key, int value) {
		if (!IsLiveTrading() || stateCollection == NULL) {
			return;
		}

		ensureDocument();
		stateDocument.setProperty(key, (long)value);
		flush();
	}

	void GetInt(string key, int &value, int defaultValue) {
		if (stateDocument != NULL && stateDocument.hasValue(key)) {
			value = (int)stateDocument.getNumber(key);
			return;
		}

		value = defaultValue;
	}

	void SetString(string key, string value) {
		if (!IsLiveTrading() || stateCollection == NULL) {
			return;
		}

		ensureDocument();
		stateDocument.setProperty(key, value);
		flush();
	}

	void GetString(string key, string &value, string defaultValue) {
		if (stateDocument != NULL && stateDocument.hasValue(key)) {
			value = stateDocument.getString(key);
			return;
		}

		value = defaultValue;
	}

	void SetBool(string key, bool value) {
		if (!IsLiveTrading() || stateCollection == NULL) {
			return;
		}

		ensureDocument();
		stateDocument.setProperty(key, value);
		flush();
	}

	void GetBool(string key, bool &value, bool defaultValue) {
		if (stateDocument != NULL && stateDocument.hasValue(key)) {
			value = stateDocument.getBoolean(key);
			return;
		}

		value = defaultValue;
	}

	void SetDatetime(string key, datetime value) {
		if (!IsLiveTrading() || stateCollection == NULL) {
			return;
		}

		ensureDocument();
		stateDocument.setProperty(key, (long)value);
		flush();
	}

	void GetDatetime(string key, datetime &value, datetime defaultValue) {
		if (stateDocument != NULL && stateDocument.hasValue(key)) {
			value = (datetime)stateDocument.getNumber(key);
			return;
		}

		value = defaultValue;
	}
};

#endif
