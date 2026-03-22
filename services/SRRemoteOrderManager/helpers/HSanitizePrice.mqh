#ifndef __H_SANITIZE_PRICE_MQH__
#define __H_SANITIZE_PRICE_MQH__

const double MAX_VALID_PRICE = 1e10;

double SanitizePrice(double price) {
	if (MathAbs(price) > MAX_VALID_PRICE) {
		return 0.0;
	}

	return price;
}

#endif
