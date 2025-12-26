#ifndef __ASSET_GBPCAD_MQH__
#define __ASSET_GBPCAD_MQH__

#include "Asset.mqh"

input group "[GBPCAD]";

#include "../strategies/Test/Test.mqh"

class GBPCAD:
public SEAsset {
public:
	GBPCAD() {
		SetName("gbpcad");
		SetSymbol("GBPCAD");
		SetMagicNumber(200);

		Setup();
	}

	void Setup() {
		SetNewStrategy(new Test());
	}
};

#endif
