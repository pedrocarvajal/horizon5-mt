#ifndef __SE_REQUEST_MQH__
#define __SE_REQUEST_MQH__

#include "../../libraries/Json/index.mqh"

#include "structs/SRequestResponse.mqh"

#include "../SELogger/SELogger.mqh"

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

	SRequestResponse execute(const string method, const string url, const char &data[], int effectiveTimeout, const string headers = "", int slowThreshold = 1000) {
		SRequestResponse response;
		char result[];
		string resultHeaders;
		string finalHeaders = (headers == "") ? defaultHeaders : headers;
		ulong startTime = GetTickCount64();

		ResetLastError();
		int status = WebRequest(method, url, finalHeaders, effectiveTimeout, data, result, resultHeaders);

		response.delay = GetTickCount64() - startTime;
		response.status = status;

		if (slowThreshold > 0 && response.delay > (ulong)slowThreshold) {
			logger.Warning(StringFormat("Slow request: %dms %s %s", response.delay, method, url));
		}

		if (status == -1) {
			int errorCode = GetLastError();
			string reason = errorCode == 4014 ? "URL not in allowed list" : "Connection failed";
			logger.Error(StringFormat("%s: error=%d %s %s", reason, errorCode, method, url));
			logRequestBody(data);
			response.body = "";
			return response;
		}

		response.body = CharArrayToString(result);

		if (status >= 400) {
			logger.Error(StringFormat("HTTP %d %s %s", status, method, url));
			logRequestBody(data);
			logger.Error(StringFormat("Response: %s", response.body));
		}

		return response;
	}

	void logRequestBody(const char &data[]) {
		int dataSize = ArraySize(data);

		if (dataSize == 0) {
			return;
		}

		string requestBody = CharArrayToString(data, 0, MathMin(dataSize, 500));
		logger.Error(StringFormat("Request: %s", requestBody));
	}

public:
	SERequest(const string url, int maxTimeout = 5000) {
		baseUrl = url;
		defaultHeaders = "";
		timeout = maxTimeout;
		logger.SetPrefix("SERequest");
	}

	SRequestResponse Get(const string path, int customTimeout = 0, int slowThreshold = 1000) {
		string url = buildUrl(path);
		char data[];
		ArrayResize(data, 0);
		int effectiveTimeout = (customTimeout > 0) ? customTimeout : timeout;

		return execute("GET", url, data, effectiveTimeout, "", slowThreshold);
	}

	SRequestResponse Post(const string path, JSON::Object &body, int customTimeout = 0, const string extraHeaders = "", int slowThreshold = 1000) {
		string url = buildUrl(path);
		string bodyString = body.toString();
		int effectiveTimeout = (customTimeout > 0) ? customTimeout : timeout;
		string headers = (extraHeaders != "") ? defaultHeaders + extraHeaders : "";

		char data[];
		StringToCharArray(bodyString, data, 0, StringLen(bodyString), CP_UTF8);

		return execute("POST", url, data, effectiveTimeout, headers, slowThreshold);
	}

	SRequestResponse Patch(const string path, JSON::Object &body, int customTimeout = 0, int slowThreshold = 1000) {
		string url = buildUrl(path);
		string bodyString = body.toString();
		int effectiveTimeout = (customTimeout > 0) ? customTimeout : timeout;

		char data[];
		StringToCharArray(bodyString, data, 0, StringLen(bodyString), CP_UTF8);

		return execute("PATCH", url, data, effectiveTimeout, "", slowThreshold);
	}

	SRequestResponse PostMultipart(const string path, const string fieldName, const string fileName, char &fileData[], const string contentType = "text/csv") {
		string url = buildUrl(path);
		string boundary = "----HorizonBoundary9876543210";

		string preamble =
			"--" + boundary + "\r\n" +
			"Content-Disposition: form-data; name=\"" + fieldName + "\"; filename=\"" + fileName + "\"\r\n" +
			"Content-Type: " + contentType + "\r\n" +
			"\r\n";

		string closing = "\r\n--" + boundary + "--\r\n";

		char preambleData[];
		StringToCharArray(preamble, preambleData, 0, StringLen(preamble), CP_UTF8);

		char closingData[];
		StringToCharArray(closing, closingData, 0, StringLen(closing), CP_UTF8);

		int preambleSize = ArraySize(preambleData);
		int fileSize = ArraySize(fileData);
		int closingSize = ArraySize(closingData);

		char data[];
		ArrayResize(data, preambleSize + fileSize + closingSize);
		ArrayCopy(data, preambleData, 0, 0, preambleSize);
		ArrayCopy(data, fileData, preambleSize, 0, fileSize);
		ArrayCopy(data, closingData, preambleSize + fileSize, 0, closingSize);

		string headers = "";
		int searchPos = 0;
		while (searchPos < StringLen(defaultHeaders)) {
			int lineEnd = StringFind(defaultHeaders, "\r\n", searchPos);
			if (lineEnd < 0) {
				break;
			}
			string line = StringSubstr(defaultHeaders, searchPos, lineEnd - searchPos);
			searchPos = lineEnd + 2;
			if (StringFind(line, "Content-Type:") == 0) {
				continue;
			}
			headers += line + "\r\n";
		}
		headers += "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";

		return execute("POST", url, data, timeout, headers);
	}

	void AddHeader(const string key, const string value) {
		defaultHeaders += key + ": " + value + "\r\n";
	}
};

#endif
