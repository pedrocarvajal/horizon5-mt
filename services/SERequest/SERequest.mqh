#ifndef __SE_REQUEST_MQH__
#define __SE_REQUEST_MQH__

#include "../SELogger/SELogger.mqh"
#include "../../libraries/json/index.mqh"

class SERequest {
private:
	string baseUrl;
	string defaultHeaders;
	int timeout;
	SELogger logger;

	string buildUrl(const string path) {
		if (StringFind(path, "http://") == 0 || StringFind(path, "https://") == 0) {
			return path;
		}

		bool baseHasTrailing = StringSubstr(baseUrl, StringLen(baseUrl) - 1) == "/";
		bool pathHasLeading = StringSubstr(path, 0, 1) == "/";

		if (baseHasTrailing && pathHasLeading) {
			return StringSubstr(baseUrl, 0, StringLen(baseUrl) - 1) + path;
		}

		if (!baseHasTrailing && !pathHasLeading) {
			return baseUrl + "/" + path;
		}

		return baseUrl + path;
	}

	string execute(const string method, const string url, const char &data[], int effectiveTimeout, const string headers = "") {
		char result[];
		string resultHeaders;
		string finalHeaders = (headers == "") ? defaultHeaders : headers;

		ResetLastError();
		int status = WebRequest(method, url, finalHeaders, effectiveTimeout, data, result, resultHeaders);

		if (status == -1) {
			int errorCode = GetLastError();
			string reason = errorCode == 4014 ? "URL not in allowed list" : "Connection failed";
			logger.Error(StringFormat("%s: error=%d %s %s", reason, errorCode, method, url));
			logger.Debug("Sent: " + CharArrayToString(data));
			return "";
		}

		if (status >= 400) {
			string responseBody = CharArrayToString(result);
			logger.Error(StringFormat("HTTP %d %s %s", status, method, url));
			logger.Debug("Sent: " + CharArrayToString(data));
			logger.Debug("Response: " + responseBody);
			return responseBody;
		}

		return CharArrayToString(result);
	}

public:
	SERequest(const string url, int maxTimeout = 5000) {
		baseUrl = url;
		defaultHeaders = "";
		timeout = maxTimeout;
		logger.SetPrefix("SERequest");
	}

	string Get(const string path, int customTimeout = 0) {
		string url = buildUrl(path);
		char data[];
		ArrayResize(data, 0);
		int effectiveTimeout = (customTimeout > 0) ? customTimeout : timeout;

		return execute("GET", url, data, effectiveTimeout);
	}

	string Post(const string path, JSON::Object &body, int customTimeout = 0, const string extraHeaders = "") {
		string url = buildUrl(path);
		string bodyString = body.toString();
		int effectiveTimeout = (customTimeout > 0) ? customTimeout : timeout;
		string headers = (extraHeaders != "") ? defaultHeaders + extraHeaders : "";

		char data[];
		StringToCharArray(bodyString, data, 0, StringLen(bodyString), CP_UTF8);

		return execute("POST", url, data, effectiveTimeout, headers);
	}

	void AddHeader(const string key, const string value) {
		defaultHeaders += key + ": " + value + "\r\n";
	}
};

#endif
