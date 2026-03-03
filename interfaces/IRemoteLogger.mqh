#ifndef __I_REMOTE_LOGGER_MQH__
#define __I_REMOTE_LOGGER_MQH__

class IRemoteLogger {
public:
	virtual void StoreLog(string level, string message, ulong magicNumber = 0) = 0;
};

#endif
