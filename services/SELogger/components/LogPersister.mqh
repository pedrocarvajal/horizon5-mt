#ifndef __LOG_PERSISTER_MQH__
#define __LOG_PERSISTER_MQH__

class LogPersister {
private:
	static string entries[];

public:
	static void Append(string entry) {
		int size = ArraySize(entries);
		ArrayResize(entries, size + 1, size + 64);
		entries[size] = entry;
	}

	static void GetAll(string &result[]) {
		int size = ArraySize(entries);
		ArrayResize(result, size);

		for (int i = 0; i < size; i++) {
			result[i] = entries[i];
		}
	}

	static int GetCount() {
		return ArraySize(entries);
	}

	static void Clear() {
		ArrayResize(entries, 0);
	}
};

string LogPersister::entries[];

#endif
