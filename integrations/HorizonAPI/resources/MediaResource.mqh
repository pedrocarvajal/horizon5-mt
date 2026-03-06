#ifndef __MEDIA_RESOURCE_MQH__
#define __MEDIA_RESOURCE_MQH__

#include "../HorizonAPIContext.mqh"

class MediaResource {
private:
	HorizonAPIContext * context;
	SELogger logger;

public:
	MediaResource(HorizonAPIContext * ctx) {
		context = ctx;
		logger.SetPrefix("MediaResource");
	}

	string Upload(string fileName, char &fileData[], string contentType = "text/csv") {
		string path = StringFormat("api/v1/account/%d/media/upload/", context.GetAccountId());

		SRequestResponse response = context.PostMultipart(path, "file", fileName, fileData, contentType);

		if (response.status != 201) {
			logger.Error(StringFormat("Upload failed with status %d for file %s", response.status, fileName));
			return "";
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Error("Upload response missing 'data' object");
			return "";
		}

		JSON::Object *dataObject = root.getObject("data");
		return dataObject.getString("file_name");
	}
};

#endif
