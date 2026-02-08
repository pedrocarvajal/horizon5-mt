#ifndef __SE_LOGGER_MQH__
#define __SE_LOGGER_MQH__

class SELogger {
private:
	string prefix;

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

	void debug(string message) {
		Print("[DEBUG] ", prefix, ": ", message);
	}

	void error(string message) {
		Print("[ERROR] ", prefix, ": ", message);
	}

	void info(string message) {
		Print("[INFO] ", prefix, ": ", message);
	}

	void separator(string title) {
		Print("[INFO] ", prefix, ": ", title,
		      " -------------------------------- ");
	}

	void warning(string message) {
		Print("[WARNING] ", prefix, ": ", message);
	}
};

#endif
