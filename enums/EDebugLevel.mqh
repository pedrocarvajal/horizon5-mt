#ifndef __E_DEBUG_LEVEL_MQH__
#define __E_DEBUG_LEVEL_MQH__

enum ENUM_DEBUG_LEVEL {
	DEBUG_LEVEL_NONE,            // No logs
	DEBUG_LEVEL_ERRORS,          // Errors & Warnings
	DEBUG_LEVEL_ERRORS_PERSIST,  // Errors & Warnings (with file persistence)
	DEBUG_LEVEL_ALL,             // All logs
	DEBUG_LEVEL_ALL_PERSIST      // All logs (with file persistence)
};

#endif
