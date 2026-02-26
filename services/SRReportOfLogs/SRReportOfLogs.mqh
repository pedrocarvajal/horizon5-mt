#ifndef __SR_REPORT_OF_LOGS_MQH__
#define __SR_REPORT_OF_LOGS_MQH__

#include "../SELogger/SELogger.mqh"
#include "../SEDb/SEDb.mqh"

class SRReportOfLogs {
private:
	SELogger logger;
	SEDb database;
	bool initialized;

public:
	SRReportOfLogs() {
		logger.SetPrefix("SRReportOfLogs");
		initialized = false;
	}

	void Initialize(string basePath) {
		database.Initialize(basePath, true);
		initialized = true;
	}

	void Export(string collectionName, string &entries[]) {
		int entryCount = ArraySize(entries);

		if (!initialized || entryCount == 0) {
			return;
		}

		SEDbCollection *collection = database.Collection(collectionName);
		collection.SetAutoFlush(false);

		for (int i = 0; i < entryCount; i++) {
			JSON::Object *document = new JSON::Object();
			document.setProperty("index", i);
			document.setProperty("entry", entries[i]);
			collection.InsertOne(document);
			delete document;
		}

		collection.Flush();

		logger.Info(StringFormat(
			"Exported %d log entries to %s",
			entryCount,
			collectionName
		));
	}
};

#endif
