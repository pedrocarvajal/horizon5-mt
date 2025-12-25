#ifndef __LOGGER_MQH__
#define __LOGGER_MQH__

class Logger {
private:
	string prefix;
	string warnings[];
	string errors[];

public:
	Logger() {
		prefix = "";
	}

	Logger(string _prefix) {
		prefix = _prefix;
	}

	void SetPrefix(string _prefix) {
		prefix = _prefix;
	}

	void info(string message) {
		Print("[INFO] ", prefix, ": ", message);
	}

	void warning(string message) {
		string full_message = "[WARNING] " + prefix + ": " + message;
		Print(full_message);

		int size = ArraySize(warnings);
		ArrayResize(warnings, size + 1);
		warnings[size] = full_message;
	}

	void error(string message) {
		string full_message = "[ERROR] " + prefix + ": " + message;
		Print(full_message);

		int size = ArraySize(errors);
		ArrayResize(errors, size + 1);
		errors[size] = full_message;
	}

	void debug(string message) {
		Print("[DEBUG] ", prefix, ": ", message);
	}

	void trace(string message) {
		Print("[TRACE] ", prefix, ": ", message);
	}

	void log(string level, string message) {
		Print("[", level, "] ", prefix, ": ", message);
	}

	void separator(string title) {
		Print("[INFO] ", prefix, ": ", title, " -------------------------------- ");
	}

	void PrintTracebackOfErrors() {
		separator("Traceback of Errors");
		for (int i = 0; i < ArraySize(errors); i++)
			Print(errors[i]);

		separator("Traceback of Warnings");
		for (int i = 0; i < ArraySize(warnings); i++)
			Print(warnings[i]);
	}
};

#endif
