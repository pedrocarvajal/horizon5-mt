#ifndef __ACCOUNT_ENROLLER_MQH__
#define __ACCOUNT_ENROLLER_MQH__

#include "../../../entities/EAccount.mqh"

#include "../../../helpers/HGetAccountUuid.mqh"
#include "../helpers/HBuildAccountJson.mqh"

#include "../../SELogger/SELogger.mqh"

#include "../../SEDb/SEDb.mqh"

#include "MetadataExporter.mqh"

class AccountEnroller {
private:
	SELogger logger;
	SEDbCollection *accountsCollection;
	MetadataExporter *metadataExporter;

public:
	AccountEnroller() {
		logger.SetPrefix("MonitorSeed::AccountEnroller");
		accountsCollection = NULL;
		metadataExporter = NULL;
	}

	void Initialize(SEDbCollection *accounts, MetadataExporter *exporter) {
		accountsCollection = accounts;
		metadataExporter = exporter;
	}

	string Enroll(EAccount &tradingAccount) {
		string accountUuid = GetDeterministicAccountUuid(tradingAccount.GetNumber(), tradingAccount.GetBrokerServer());

		if (EnableSeedAccounts) {
			JSON::Object *json = BuildAccountJson(tradingAccount, accountUuid);
			accountsCollection.InsertOne(json);
			delete json;
		}

		if (EnableSeedMetadata) {
			JSON::Array *metadataEntries = tradingAccount.GetMetadata();
			metadataExporter.ExportAccountMetadata(metadataEntries, accountUuid);
			delete metadataEntries;
		}

		logger.Info(
			LOG_CODE_STATS_EXPORT_FAILED,
			StringFormat(
				"Enrolled account %lld -> %s",
				tradingAccount.GetNumber(),
				accountUuid
		));

		return accountUuid;
	}
};

#endif
