#ifndef __ASSET_GBPCAD_MQH__
#define __ASSET_GBPCAD_MQH__

#include "../interfaces/Asset.mqh"
#include "../strategies/Test/Test.mqh"

class GBPCAD:
public IAsset {
public:
	GBPCAD() {
		SetName("gbpcad");
		SetSymbol("GBPCAD");

		SetupStrategies();
	}

	void SetupStrategies() {
		SetNewStrategy(new Test(symbol));
	}
};

#endif
