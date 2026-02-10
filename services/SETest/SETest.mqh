#ifndef __SE_TEST_MQH__
#define __SE_TEST_MQH__

#include "../SELogger/SELogger.mqh"

class SETest {
private:
	SELogger logger;
	string suiteName;
	int passed;
	int failed;

	void Record(bool condition, string testName) {
		if (condition) {
			passed++;
			logger.info(StringFormat("PASS: %s", testName));
		} else {
			failed++;
			logger.error(StringFormat("FAIL: %s", testName));
		}
	}

public:
	SETest() {
		suiteName = "SETest";
		passed = 0;
		failed = 0;

		logger.SetPrefix("SETest");
	}

	void SetSuiteName(string name) {
		suiteName = name;
		logger.SetPrefix(name);
	}

	void Describe(string section) {
		logger.separator(section);
	}

	void Assert(bool condition, string testName) {
		Record(condition, testName);
	}

	void AssertTrue(bool value, string testName) {
		Record(value == true, testName);
	}

	void AssertFalse(bool value, string testName) {
		Record(value == false, testName);
	}

	void AssertEquals(string actual, string expected, string testName) {
		bool match = actual == expected;

		if (!match)
			logger.debug(StringFormat("  Expected: \"%s\", Got: \"%s\"", expected, actual));

		Record(match, testName);
	}

	void AssertEquals(int actual, int expected, string testName) {
		bool match = actual == expected;

		if (!match)
			logger.debug(StringFormat("  Expected: %d, Got: %d", expected, actual));

		Record(match, testName);
	}

	void AssertEquals(double actual, double expected, string testName) {
		bool match = MathAbs(actual - expected) < 0.0000001;

		if (!match)
			logger.debug(StringFormat("  Expected: %f, Got: %f", expected, actual));

		Record(match, testName);
	}

	void AssertEquals(long actual, long expected, string testName) {
		bool match = actual == expected;

		if (!match)
			logger.debug(StringFormat("  Expected: %lld, Got: %lld", expected, actual));

		Record(match, testName);
	}

	void AssertNotEquals(string actual, string notExpected, string testName) {
		bool match = actual != notExpected;

		if (!match)
			logger.debug(StringFormat("  Should not be: \"%s\"", notExpected));

		Record(match, testName);
	}

	void AssertNotEquals(int actual, int notExpected, string testName) {
		bool match = actual != notExpected;

		if (!match)
			logger.debug(StringFormat("  Should not be: %d", notExpected));

		Record(match, testName);
	}

	void AssertNotEquals(double actual, double notExpected, string testName) {
		bool match = MathAbs(actual - notExpected) >= 0.0000001;

		if (!match)
			logger.debug(StringFormat("  Should not be: %f", notExpected));

		Record(match, testName);
	}

	void AssertGreaterThan(double actual, double threshold, string testName) {
		bool match = actual > threshold;
		if (!match)
			logger.debug(StringFormat("  Expected > %f, Got: %f", threshold, actual));
		Record(match, testName);
	}

	void AssertLessThan(double actual, double threshold, string testName) {
		bool match = actual < threshold;

		if (!match)
			logger.debug(StringFormat("  Expected < %f, Got: %f", threshold, actual));

		Record(match, testName);
	}

	void AssertGreaterThanOrEqual(double actual, double threshold, string testName) {
		bool match = actual >= threshold;

		if (!match)
			logger.debug(StringFormat("  Expected >= %f, Got: %f", threshold, actual));

		Record(match, testName);
	}

	void AssertLessThanOrEqual(double actual, double threshold, string testName) {
		bool match = actual <= threshold;

		if (!match)
			logger.debug(StringFormat("  Expected <= %f, Got: %f", threshold, actual));

		Record(match, testName);
	}

	void AssertNull(void *pointer, string testName) {
		Record(pointer == NULL, testName);
	}

	void AssertNotNull(void *pointer, string testName) {
		Record(pointer != NULL, testName);
	}

	void AssertContains(string haystack, string needle, string testName) {
		bool match = StringFind(haystack, needle) != -1;

		if (!match)
			logger.debug(StringFormat("  \"%s\" not found in \"%s\"", needle, haystack));

		Record(match, testName);
	}

	int GetPassed() {
		return passed;
	}

	int GetFailed() {
		return failed;
	}

	int GetTotal() {
		return passed + failed;
	}

	bool HasFailed() {
		return failed > 0;
	}

	void PrintSummary() {
		logger.separator(StringFormat("%s - Summary", suiteName));
		logger.info(StringFormat("Results: %d passed, %d failed, %d total", passed, failed, passed + failed));

		if (failed > 0)
			logger.error(StringFormat("%d test(s) FAILED", failed));
		else
			logger.info("All tests PASSED");
	}
};

#endif
