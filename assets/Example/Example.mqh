#ifndef __ASSET_EXAMPLE_MQH__
#define __ASSET_EXAMPLE_MQH__

#include "../Asset.mqh"

#include "../../strategies/Test/Test.mqh"

input group "[Example]";
input bool ExampleEnabled = false;
input bool ExampleTest = false;

class ExampleAsset:
public SEAsset {
public:
	ExampleAsset() {
		SetName("example");
		SetSymbol("EURUSDm");
		SetEnabled(ExampleEnabled);

		Setup();
	}

	void Setup() {
		if (ExampleTest)
			SetNewStrategy(new Test());
	}
};

#endif
