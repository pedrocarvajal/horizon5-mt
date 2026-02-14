#ifndef __SE_LOGGER_MQH__
#define __SE_LOGGER_MQH__

class SELogger {
private:
	string prefix;
	string entries[];

	void log(string level, string message) {
		Print("[", level, "] ", prefix, ": ", message);

		if (!EnableDebugLogs)
			return;

		int size = ArraySize(entries);
		ArrayResize(entries, size + 1);
		entries[size] = StringFormat("[%s] %s: %s", level, prefix, message);
	}

public:
	SELogger() {
		prefix = "";
	}

	SELogger(string newPrefix) {
		prefix = newPrefix;
	}

	void SetPrefix(string newPrefix) {
		prefix = newPrefix;
	}

	int GetEntryCount() {
		return ArraySize(entries);
	}

	void GetEntries(string &result[]) {
		ArrayResize(result, ArraySize(entries));

		for (int i = 0; i < ArraySize(entries); i++) {
			result[i] = entries[i];
		}
	}

	void ClearEntries() {
		ArrayResize(entries, 0);
	}

	void Debug(string message) {
		log("DEBUG", message);
	}

	void Error(string message) {
		log("ERROR", message);
	}

	void Info(string message) {
		log("INFO", message);
	}

	void Warning(string message) {
		log("WARNING", message);
	}

	void Separator(string title) {
		log("INFO", title + " -------------------------------- ");
	}
};

#endif
