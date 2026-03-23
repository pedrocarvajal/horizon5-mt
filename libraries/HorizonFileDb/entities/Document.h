#ifndef HORIZON_FDB_DOCUMENT_H
#define HORIZON_FDB_DOCUMENT_H

#include <rapidjson/document.h>
#include <rapidjson/writer.h>
#include <rapidjson/stringbuffer.h>

#include <string>

struct FdbDocument {
    rapidjson::Document dom;
    std::string cachedId;

    FdbDocument()
    {
        dom.SetObject();
    }

    bool ParseFromUtf8(const char* json)
    {
        dom.Parse(json);

        if (dom.HasParseError()) {
            return false;
        }

        if (dom.HasMember("_id") && dom["_id"].IsString()) {
            cachedId = dom["_id"].GetString();
        }

        return true;
    }

    void SerializeToBuffer(rapidjson::Writer<rapidjson::StringBuffer>& writer) const
    {
        dom.Accept(writer);
    }

    std::string Serialize() const
    {
        rapidjson::StringBuffer buffer;
        rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
        dom.Accept(writer);
        return std::string(buffer.GetString(), buffer.GetSize());
    }
};

#endif
