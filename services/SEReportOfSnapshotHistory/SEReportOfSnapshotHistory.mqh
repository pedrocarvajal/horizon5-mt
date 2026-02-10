#ifndef __SE_REPORT_OF_SNAPSHOT_HISTORY_MQH__
#define __SE_REPORT_OF_SNAPSHOT_HISTORY_MQH__

#include "../../libraries/json/index.mqh"
#include "../../structs/SSStatisticsSnapshot.mqh"
#include "../../structs/SSOrderHistory.mqh"
#include "../SELogger/SELogger.mqh"
#include "../SEDateTime/SEDateTime.mqh"
#include "../SEDateTime/structs/SDateTime.mqh"

extern SEDateTime dtime;

class SEReportOfSnapshotHistory {
private:
	SELogger logger;

	string reportsDir;
	string reportName;
	bool useCommonFiles;
	SSStatisticsSnapshot snapshotHistory[];

	void initialize(string directory, string name, bool useCommon) {
		logger.SetPrefix("SnapshotHistoryReporter");
		reportsDir = directory;
		reportName = name;
		useCommonFiles = useCommon;
		ArrayResize(snapshotHistory, 0);
	}

	JSON::Object *SnapshotToJson(const SSStatisticsSnapshot &snapshot) {
		JSON::Object *obj = new JSON::Object();
		obj.setProperty("timestamp", (long)snapshot.timestamp);
		obj.setProperty("id", snapshot.id);

		obj.setProperty("nav_peak", snapshot.navPeak);
		obj.setProperty("drawdown_max_in_dollars", snapshot.drawdownMaxInDollars);
		obj.setProperty("drawdown_max_in_percentage", snapshot.drawdownMaxInPercentage);
		obj.setProperty("winning_orders", snapshot.winningOrders);
		obj.setProperty("winning_orders_performance", snapshot.winningOrdersPerformance);
		obj.setProperty("losing_orders", snapshot.losingOrders);
		obj.setProperty("losing_orders_performance", snapshot.losingOrdersPerformance);
		obj.setProperty("max_loss", snapshot.maxLoss);

		obj.setProperty("r_squared", snapshot.rSquared);
		obj.setProperty("sharpe_ratio", snapshot.sharpeRatio);
		obj.setProperty("risk_reward_ratio", snapshot.riskRewardRatio);
		obj.setProperty("win_rate", snapshot.winRate);
		obj.setProperty("recovery_factor", snapshot.recoveryFactor);
		obj.setProperty("cagr", snapshot.cagr);
		obj.setProperty("stability", snapshot.stability);
		obj.setProperty("stability_sq3", snapshot.stabilitySQ3);

		obj.setProperty("quality", snapshot.quality);
		obj.setProperty("quality_reason", snapshot.qualityReason);

		obj.setProperty("max_exposure_in_lots", snapshot.maxExposureInLots);
		obj.setProperty("max_exposure_in_percentage", snapshot.maxExposureInPercentage);

		return obj;
	}

	JSON::Array *SnapshotArrayToJsonArray(
		const SSStatisticsSnapshot &snapshots[],
		int count
	) {
		JSON::Array *arr = new JSON::Array();

		for (int i = 0; i < count; i++)
			arr.add(SnapshotToJson(snapshots[i]));

		return arr;
	}

	JSON::Object *BuildJsonReport() {
		JSON::Object *root = new JSON::Object();
		root.setProperty("name", "Snapshot History Report");

		if (ArraySize(snapshotHistory) == 0) {
			logger.warning("No snapshot history data to export - creating empty report");
			JSON::Array *emptyArray = new JSON::Array();
			root.setProperty("data", emptyArray);
		} else {
			root.setProperty("data", SnapshotArrayToJsonArray(snapshotHistory, ArraySize(snapshotHistory)));
		}

		return root;
	}

public:
	SEReportOfSnapshotHistory() {
		initialize(
			StringFormat("/Reports/%s/%lld", _Symbol, (long)dtime.Timestamp()),
			"Snapshots",
			false
		);
	}

	SEReportOfSnapshotHistory(string customDir, bool useCommonFolder = false, string customReportName = "Snapshots") {
		initialize(customDir, customReportName, useCommonFolder);
	}

	void AddSnapshot(const SSStatisticsSnapshot &snapshot) {
		ArrayResize(snapshotHistory, ArraySize(snapshotHistory) + 1);
		snapshotHistory[ArraySize(snapshotHistory) - 1] = snapshot;
	}

	void ExportSnapshotHistoryToJsonFile() {
		JSON::Object *root = BuildJsonReport();
		string jsonStr = root.toString();
		string filename = StringFormat("%s/%s.json", reportsDir, reportName);
		int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;

		if (useCommonFiles)
			flags |= FILE_COMMON;

		logger.debug(StringFormat(
			"Exporting %d snapshots to %s (full: %s\\%s.json)",
			ArraySize(snapshotHistory), filename, GetCurrentReportsPath(), reportName
		));

		int file = FileOpen(filename, flags);

		if (file == INVALID_HANDLE) {
			int errorCode = GetLastError();

			logger.error(StringFormat(
				"Cannot create snapshot history file '%s' - Error code: %d",
				filename,
				errorCode
			));

			logger.error(StringFormat(
				"Flags used: %d (FILE_WRITE=%d, FILE_TXT=%d, FILE_ANSI=%d, FILE_COMMON=%d)",
				flags,
				FILE_WRITE,
				FILE_TXT,
				FILE_ANSI,
				FILE_COMMON
			));
		} else {
			FileWriteString(file, jsonStr);
			FileClose(file);

			logger.info(StringFormat(
				"Snapshot history saved - %s.json with %d snapshots",
				reportName,
				ArraySize(snapshotHistory)
			));
		}

		delete root;
	}

	void PrintCurrentPath() {
		logger.info(StringFormat("Snapshot history reports saved to: %s", GetCurrentReportsPath()));
	}

	int GetSnapshotCount() {
		return ArraySize(snapshotHistory);
	}

	string GetCurrentReportsPath() {
		string pathSeparator = "\\";
		string convertedDir = reportsDir;
		StringReplace(convertedDir, "/", pathSeparator);

		if (useCommonFiles) {
			return StringFormat("%s%sFiles%s",
				TerminalInfoString(TERMINAL_COMMONDATA_PATH),
				pathSeparator,
				convertedDir
			);
		} else {
			return StringFormat("%s%sMQL5%sFiles%s",
				TerminalInfoString(TERMINAL_DATA_PATH),
				pathSeparator,
				pathSeparator,
				convertedDir
			);
		}
	}
};

#endif
