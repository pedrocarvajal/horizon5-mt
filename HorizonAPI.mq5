#property service
#property copyright "Horizon5"
#property version   "1.00"
#property strict

#include "enums/EDebugLevel.mqh"
#include "services/SELogger/SELogger.mqh"
#include "services/SEDateTime/SEDateTime.mqh"
#include "helpers/HGetLogsPath.mqh"
#include "services/SRReportOfLogs/SRReportOfLogs.mqh"
#include "helpers/HIsLiveTrading.mqh"
#include "integrations/HorizonAPI/HorizonAPI.mqh"

input group "General Settings";
input int TickIntervalTime = 60; // [1] > Tick interval (1 = 1 second by tick)
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_LEVEL_ALL; // [1] > Debug log level

input group "HorizonAPI Integration";
input bool EnableHorizonAPI = true; // [1] > Enable HorizonAPI integration
input string HorizonAPIUrl = ""; // [1] > HorizonAPI base URL
input string HorizonAPIKey = ""; // [1] > HorizonAPI key (required)

SEDateTime dtime;
SELogger logger("HorizonAPI");
HorizonAPI horizonAPI;

int OnStart() {
	SELogger::SetGlobalDebugLevel(DebugLevel);

	if (!horizonAPI.Initialize(HorizonAPIUrl, HorizonAPIKey, EnableHorizonAPI && IsLiveTrading())) {
		logger.Error("HorizonAPI initialization failed");
		return -1;
	}

	if (horizonAPI.IsEnabled()) {
		SELogger::SetRemoteLogger(GetPointer(horizonAPI));
	}

	logger.Info("Service started");

	while (!IsStopped()) {
		Sleep(TickIntervalTime * 1000);
	}

	logger.Info("Service stopped");

	if (SELogger::GetGlobalEntryCount() > 0) {
		string logEntries[];
		SELogger::GetGlobalEntries(logEntries);

		SRReportOfLogs logExporter;
		logExporter.Initialize(GetLogsPath("HorizonAPI"));
		logExporter.Export("Logs", logEntries);

		SELogger::ClearGlobalEntries();
	}

	return 0;
}
