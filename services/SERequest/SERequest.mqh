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
			logger.Warning(
				LOG_CODE_REMOTE_TIMEOUT,
				StringFormat(
					"remote request slow | delay_ms=%d method=%s url=%s",
					response.delay,
					method,
					url
			));
		}

		if (status == -1) {
			int errorCode = GetLastError();
			string reason = errorCode == 4014 ? "URL not in allowed list" : "Connection failed";
			logger.Error(
				LOG_CODE_REMOTE_HTTP_ERROR,
				StringFormat(
					"remote request failed | reason=\"%s\" error=%d method=%s url=%s",
					reason,
					errorCode,
					method,
					url
			));
			logRequestBody(data);
			response.body = "";
			return response;
		}

		response.body = CharArrayToString(result);

		if (status >= 400) {
			logger.Error(
				LOG_CODE_REMOTE_HTTP_ERROR,
				StringFormat(
					"remote request failed | status=%d method=%s url=%s",
					status,
					method,
					url
			));
			logRequestBody(data);
			logger.Error(
				LOG_CODE_REMOTE_HTTP_ERROR,
				StringFormat(
					"remote response body | body=%s",
					response.body
			));
		}

		return response;
	}

	void logRequestBody(const char &data[]) {
		int dataSize = ArraySize(data);

		if (dataSize == 0) {
			return;
		}

		string requestBody = CharArrayToString(data, 0, MathMin(dataSize, 500));
		logger.Error(
			LOG_CODE_REMOTE_HTTP_ERROR,
			StringFormat(
				"remote request body | body=%s",
				requestBody
		));
	}

public:
	SERequest(const string url) {
		baseUrl = url;
		defaultHeaders = "";
		timeout = 60000;
		logger.SetPrefix("SERequest");
	}

	SRequestResponse Get(const string path, int slowThreshold = 1000) {
		string url = buildUrl(path);
		char data[];
		ArrayResize(data, 0);

		return execute("GET", url, data, timeout, "", slowThreshold);
	}

	SRequestResponse Post(const string path, JSON::Object &body, const string extraHeaders = "", int slowThreshold = 1000) {
		string url = buildUrl(path);
		string bodyString = body.toString();
		string headers = (extraHeaders != "") ? defaultHeaders + extraHeaders : "";

		char data[];
		StringToCharArray(bodyString, data, 0, StringLen(bodyString), CP_UTF8);

		return execute("POST", url, data, timeout, headers, slowThreshold);
	}

	SRequestResponse Patch(const string path, JSON::Object &body, int slowThreshold = 1000) {
		string url = buildUrl(path);
		string bodyString = body.toString();

		char data[];
		StringToCharArray(bodyString, data, 0, StringLen(bodyString), CP_UTF8);

		return execute("PATCH", url, data, timeout, "", slowThreshold);
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
