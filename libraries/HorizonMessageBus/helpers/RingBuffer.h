#ifndef HORIZON_MB_RING_BUFFER_H
#define HORIZON_MB_RING_BUFFER_H

#include "../entities/Message.h"
#include <vector>

class RingBuffer {
private:
    std::vector<Message> buffer;
    int capacity;
    long long headSequence;
    long long tailSequence;

public:
    RingBuffer()
        : capacity(0)
        , headSequence(0)
        , tailSequence(0)
    {
    }

    void Initialize(int bufferCapacity)
    {
        capacity = bufferCapacity;
        headSequence = 0;
        tailSequence = 0;
        buffer.resize(capacity);
    }

    long long Push(const std::wstring& messageType, const std::wstring& payload, long long timestamp)
    {
        long long sequence = headSequence;
        int index = static_cast<int>(sequence % capacity);

        buffer[index] = Message(sequence, messageType, payload, timestamp);
        headSequence++;

        if (headSequence - tailSequence > capacity) {
            tailSequence = headSequence - capacity;
        }

        return sequence;
    }

    int Read(long long afterSequence, Message* results, int maxResults) const
    {
        long long startSequence = afterSequence + 1;

        if (startSequence < tailSequence) {
            startSequence = tailSequence;
        }

        int count = 0;

        for (long long seq = startSequence; seq < headSequence && count < maxResults; seq++) {
            int index = static_cast<int>(seq % capacity);

            if (buffer[index].acknowledged) {
                continue;
            }

            results[count] = buffer[index];
            count++;
        }

        return count;
    }

    void AckSequence(long long sequence)
    {
        if (sequence < tailSequence || sequence >= headSequence) {
            return;
        }

        int index = static_cast<int>(sequence % capacity);
        buffer[index].acknowledged = true;

        while (tailSequence < headSequence) {
            int tailIndex = static_cast<int>(tailSequence % capacity);

            if (!buffer[tailIndex].acknowledged) {
                break;
            }

            tailSequence++;
        }
    }

    void AdvanceTail(long long upToSequence)
    {
        AckSequence(upToSequence);
    }

    long long GetHeadSequence() const { return headSequence; }
    long long GetTailSequence() const { return tailSequence; }
    bool IsEmpty() const { return headSequence == tailSequence; }
    int GetPendingCount() const { return static_cast<int>(headSequence - tailSequence); }
};

#endif
