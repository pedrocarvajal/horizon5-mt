#ifndef __SE_ASSET_MQH__
#define __SE_ASSET_MQH__

#include "../entities/EOrder.mqh"
#include "../helpers/HIsMarketClosed.mqh"
#include "../helpers/HStringToNumber.mqh"
#include "../interfaces/IAsset.mqh"
#include "../services/SELogger/SELogger.mqh"
#include "../strategies/Strategy.mqh"

class SEAsset:
public IAsset {
private:
	SELogger logger;

	string name;
	double weight;
	bool enabled;
	double balance;

protected:
	string symbol;

public:
	SEStrategy * strategies[];

	SEAsset() {
		logger.SetPrefix("SEAsset");
		weight = 0;
		enabled = false;
	}

	~SEAsset() {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (CheckPointer(strategies[i]) != POINTER_DYNAMIC)
				continue;

			delete strategies[i];
		}
	}

	virtual int OnInit() {
		int strategyCount = ArraySize(strategies);

		if (!enabled) {
			logger.info(StringFormat(
				"Asset skipped (disabled): %s",
				name
			));

			return INIT_SUCCEEDED;
		}

		if (strategyCount == 0) {
			logger.error(StringFormat(
				"No strategies defined for enabled asset: %s",
				name));
			return INIT_FAILED;
		}

		double weightPerStrategy = weight / strategyCount;
		double balancePerStrategy = balance / strategyCount;

		for (int i = 0; i < strategyCount; i++) {
			strategies[i].SetWeight(weightPerStrategy);
			strategies[i].SetBalance(balancePerStrategy);

			int result = strategies[i].OnInit();

			if (result != INIT_SUCCEEDED) {
				logger.error(StringFormat(
					"Strategy initialization failed: %s",
					strategies[i].GetName()));
				return INIT_FAILED;
			}
		}

		logger.info(StringFormat(
			"%s initialized | symbol: %s | strategies: %d | weight: %.4f | balance: %.2f",
			name,
			symbol,
			strategyCount,
			weight,
			balance
		));

		return INIT_SUCCEEDED;
	}

	virtual int OnTesterInit() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnTesterInit();

		return INIT_SUCCEEDED;
	}

	virtual void OnTick() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnTick();
	}

	virtual void OnStartMinute() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnStartMinute();
	}

	virtual void OnStartHour() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnStartHour();
	}

	virtual void OnStartDay() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnStartDay();
	}

	virtual void OnStartWeek() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnStartWeek();
	}

	virtual void OnStartMonth() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnStartMonth();
	}

	virtual void OnOpenOrder(EOrder &order) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (order.GetSource() == strategies[i].GetPrefix()) {
				strategies[i].OnOpenOrder(order);
				break;
			}
		}
	}

	virtual void OnCloseOrder(EOrder &order, ENUM_DEAL_REASON reason) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			if (order.GetSource() == strategies[i].GetPrefix()) {
				strategies[i].OnCloseOrder(order, reason);
				break;
			}
		}
	}

	virtual void OnEndWeek() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnEndWeek();
	}

	virtual void OnDeinit() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].OnDeinit();
	}

	void AddStrategy(SEStrategy *strategy) {
		strategy.SetAsset(GetPointer(this));
		strategy.SetSymbol(symbol);
		strategy.SetMagicNumber(StringToNumber(
			StringFormat(
				"%s_%s_%s",
				symbol,
				name,
				strategy.GetName()
			)
		));

		ArrayResize(strategies, ArraySize(strategies) + 1);
		strategies[ArraySize(strategies) - 1] = strategy;
	}

	int GetStrategyCount() {
		return ArraySize(strategies);
	}

	double CalculateQualityProduct() {
		double quality = 1.0;

		for (int i = 0; i < ArraySize(strategies); i++) {
			strategies[i].GetStatistics().OnForceEnd();

			double strategyQuality =
				strategies[i].GetStatistics().GetQuality().quality;

			if (strategyQuality == 0)
				return 0;

			quality = MathPow(
				quality * strategyQuality,
				0.5
			);
		}

		return quality;
	}

	bool FindOrderByOrderId(
		ulong orderId,
		int &strategyIndex,
		int &orderIndex
	) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			int idx = strategies[i].FindOrderIndexByOrderId(orderId);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	bool FindOrderByPositionId(
		ulong positionId,
		int &strategyIndex,
		int &orderIndex
	) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			int idx = strategies[i].FindOrderIndexByPositionId(positionId);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	bool FindOrderById(string id, int &strategyIndex, int &orderIndex) {
		for (int i = 0; i < ArraySize(strategies); i++) {
			int idx = strategies[i].FindOrderIndexById(id);

			if (idx != -1) {
				strategyIndex = i;
				orderIndex = idx;
				return true;
			}
		}

		return false;
	}

	SEStrategy * GetStrategyByPrefix(string strategyPrefix) {
		for (int i = 0; i < ArraySize(strategies); i++)
			if (strategies[i].GetPrefix() == strategyPrefix)
				return strategies[i];

		return NULL;
	}

	void ProcessOrders() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].ProcessOrders();
	}

	void CleanupClosedOrders() {
		for (int i = 0; i < ArraySize(strategies); i++)
			strategies[i].CleanupClosedOrders();
	}

	void SetName(string newName) {
		name = newName;
	}

	void SetEnabled(bool newEnabled) {
		enabled = newEnabled;
	}

	void SetSymbol(string newSymbol) {
		symbol = newSymbol;
	}

	void SetWeight(double newWeight) {
		weight = newWeight;
	}

	void SetBalance(double newBalance) {
		balance = newBalance;
	}

	string GetSymbol() {
		return symbol;
	}

	bool IsEnabled() {
		return enabled;
	}
};

#endif
