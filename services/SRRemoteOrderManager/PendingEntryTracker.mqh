#ifndef __PENDING_ENTRY_TRACKER_MQH__
#define __PENDING_ENTRY_TRACKER_MQH__

#include "structs/SPendingEntry.mqh"

class PendingEntryTracker {
private:
	SPendingEntry openEntries[];
	SPendingEntry closeEntries[];

	int findIndex(const SPendingEntry &entries[], const string orderId) {
		for (int i = 0; i < ArraySize(entries); i++) {
			if (entries[i].orderId == orderId) {
				return i;
			}
		}

		return -1;
	}

	void track(SPendingEntry &entries[], const string orderId, const string eventId) {
		int size = ArraySize(entries);
		ArrayResize(entries, size + 1);
		entries[size].orderId = orderId;
		entries[size].eventId = eventId;
	}

	string consumeAt(SPendingEntry &entries[], int index) {
		string eventId = entries[index].eventId;
		int lastIndex = ArraySize(entries) - 1;

		if (index < lastIndex) {
			entries[index] = entries[lastIndex];
		}

		ArrayResize(entries, lastIndex);
		return eventId;
	}

public:
	int FindOpenIndex(const string orderId) {
		return findIndex(openEntries, orderId);
	}

	int FindCloseIndex(const string orderId) {
		return findIndex(closeEntries, orderId);
	}

	void TrackOpen(const string orderId, const string eventId) {
		track(openEntries, orderId, eventId);
	}

	void TrackClose(const string orderId, const string eventId) {
		track(closeEntries, orderId, eventId);
	}

	string ConsumeOpen(int index) {
		return consumeAt(openEntries, index);
	}

	string ConsumeClose(int index) {
		return consumeAt(closeEntries, index);
	}
};

#endif
