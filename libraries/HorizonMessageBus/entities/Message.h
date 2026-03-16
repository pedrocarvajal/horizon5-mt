#ifndef HORIZON_MB_MESSAGE_H
#define HORIZON_MB_MESSAGE_H

#include <string>

struct Message {
    long long sequence;
    std::wstring type;
    std::wstring payload;
    long long timestamp;

    Message()
        : sequence(0)
        , type()
        , payload()
        , timestamp(0)
    {
    }

    Message(long long sequenceNumber, const std::wstring& messageType,
            const std::wstring& messagePayload, long long messageTimestamp)
        : sequence(sequenceNumber)
        , type(messageType)
        , payload(messagePayload)
        , timestamp(messageTimestamp)
    {
    }
};

#endif
