#ifndef __SE_REQUEST_MQH__
#define __SE_REQUEST_MQH__

#include "../SELogger/SELogger.mqh"
#include "../../libraries/json/index.mqh"
#include "structs/SCircuitBreakerState.mqh"

class SERequest {
private:
	string baseUrl;
	string defaultHeaders;
	int timeout;
	SCircuitBreakerState circuitBreaker;
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

	bool isCircuitBreakerOpen() {
		if (circuitBreaker.state == CIRCUIT_BREAKER_CLOSED) {
			return false;
		}

		datetime currentTime = TimeCurrent();

		if (currentTime - circuitBreaker.lastFailureTime >= circuitBreaker.cooldownSeconds) {
			circuitBreaker.state = CIRCUIT_BREAKER_CLOSED;
			circuitBreaker.failureCount = 0;
			logger.Info("Circuit breaker reset to CLOSED after cooldown period");
			return false;
		}

		return true;
	}

	void handleRequestSuccess() {
		if (circuitBreaker.failureCount > 0) {
			circuitBreaker.failureCount = 0;
			circuitBreaker.state = CIRCUIT_BREAKER_CLOSED;
			logger.Info("Circuit breaker reset due to successful request");
		}
	}

	void handleRequestFailure(const string url) {
		circuitBreaker.failureCount++;
		circuitBreaker.lastFailureTime = TimeCurrent();

		logger.Warning("Request failure #" + IntegerToString(circuitBreaker.failureCount) + " for: " + url);

		if (circuitBreaker.failureCount >= circuitBreaker.failureThreshold) {
			circuitBreaker.state = CIRCUIT_BREAKER_OPEN;
			logger.Error(
				"CIRCUIT BREAKER OPENED - Too many failures (" +
				IntegerToString(circuitBreaker.failureCount) + "/" +
				IntegerToString(circuitBreaker.failureThreshold) +
				"). Requests blocked for " +
				IntegerToString(circuitBreaker.cooldownSeconds / 60) + " minutes");
		}
	}

	string execute(const string method, const string url, const char &data[], int effectiveTimeout, const string headers = "") {
		if (isCircuitBreakerOpen()) {
			logger.Warning("Request blocked by circuit breaker: " + method + " " + url);
			Sleep(1000);
			return "";
		}

		char result[];
		string resultHeaders;
		string finalHeaders = (headers == "") ? defaultHeaders : headers;

		ResetLastError();
		int status = WebRequest(method, url, finalHeaders, effectiveTimeout, data, result, resultHeaders);

		if (status == -1) {
			int errorCode = GetLastError();
			logger.Error("WebRequest error: " + IntegerToString(errorCode) + " - " + (errorCode == 4014 ? "URL not in allowed list" : "Connection failed"));
			handleRequestFailure(url);
			return "";
		}

		if (status < 200 || status >= 300) {
			string responseBody = CharArrayToString(result);
			logger.Error("HTTP " + IntegerToString(status) + " " + method + " " + url + " | " + responseBody);
			handleRequestFailure(url);
			return responseBody;
		}

		handleRequestSuccess();
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
