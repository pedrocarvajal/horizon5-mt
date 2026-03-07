#ifndef __ACCOUNT_RESOURCE_MQH__
#define __ACCOUNT_RESOURCE_MQH__

#include "../HorizonAPIContext.mqh"
#include "../structs/SHorizonAccount.mqh"
#include "../helpers/HGetSafeMarginLevel.mqh"
#include "../../../helpers/HClampNumeric.mqh"

class AccountResource {
private:
	HorizonAPIContext * context;
	SELogger logger;

public:
	AccountResource(HorizonAPIContext * ctx) {
		context = ctx;
		logger.SetPrefix("AccountResource");
	}

	void Upsert() {
		double balance = ClampNumeric(AccountInfoDouble(ACCOUNT_BALANCE), 13, 2);
		double equity = ClampNumeric(AccountInfoDouble(ACCOUNT_EQUITY), 13, 2);

		JSON::Object body;
		body.setProperty("account_id", context.GetAccountId());
		body.setProperty("broker", AccountInfoString(ACCOUNT_COMPANY));
		body.setProperty("server", AccountInfoString(ACCOUNT_SERVER));
		body.setProperty("currency", AccountInfoString(ACCOUNT_CURRENCY));
		body.setProperty("leverage", (int)AccountInfoInteger(ACCOUNT_LEVERAGE));
		body.setProperty("balance", balance);
		body.setProperty("equity", equity);
		body.setProperty("margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN), 13, 2));
		body.setProperty("free_margin", ClampNumeric(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 13, 2));
		body.setProperty("profit", ClampNumeric(AccountInfoDouble(ACCOUNT_PROFIT), 13, 2));
		body.setProperty("margin_level", ClampNumeric(GetSafeMarginLevel(), 8, 2));

		context.Post("api/v1/account/", body);
	}

	SHorizonAccount Fetch() {
		SHorizonAccount account;
		account.status = "active";

		string path = StringFormat("api/v1/account/%d/", context.GetAccountId());

		SRequestResponse response = context.Get(path);

		if (response.status != 200 || response.body == "") {
			logger.Warning("Fetch: request failed — assuming account is active");
			return account;
		}

		JSON::Object root(response.body);

		if (!root.isObject("data")) {
			logger.Warning("Fetch: response missing 'data' object — assuming account is active");
			return account;
		}

		JSON::Object *accountObject = root.getObject("data");

		if (accountObject == NULL) {
			logger.Warning("Fetch: failed to parse account object — assuming account is active");
			return account;
		}

		account.status = accountObject.getString("status");
		account.broker = accountObject.getString("broker");
		account.server = accountObject.getString("server");
		account.currency = accountObject.getString("currency");
		account.leverage = (int)accountObject.getNumber("leverage");
		account.balance = accountObject.getNumber("balance");
		account.equity = accountObject.getNumber("equity");
		account.margin = accountObject.getNumber("margin");
		account.freeMargin = accountObject.getNumber("free_margin");
		account.profit = accountObject.getNumber("profit");
		account.marginLevel = accountObject.getNumber("margin_level");

		logger.Info(StringFormat("Account status: %s", account.status));

		return account;
	}
};

#endif
