#ifndef __H_FORMAT_LOG_FIELDS_MQH__
#define __H_FORMAT_LOG_FIELDS_MQH__

string HFormatLogFields(const string &keys[], const string &values[]) {
	int count = MathMin(ArraySize(keys), ArraySize(values));
	string result = "";

	for (int i = 0; i < count; i++) {
		if (values[i] == "") {
			continue;
		}

		string formatted = StringFind(values[i], " ") >= 0
			? StringFormat("%s='%s'", keys[i], values[i])
			: keys[i] + "=" + values[i];

		if (result != "") {
			result += " ";
		}

		result += formatted;
	}

	return result;
}

#endif
