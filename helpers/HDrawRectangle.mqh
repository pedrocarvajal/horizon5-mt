#ifndef __H_DRAW_RECTANGLE_MQH__
#define __H_DRAW_RECTANGLE_MQH__

bool drawRectangle(
	string name,
	datetime time1,
	double price1,
	datetime time2,
	double price2,
	color rectColor = clrWhite,
	ENUM_LINE_STYLE style = STYLE_SOLID,
	int width = 1,
	long chartId = 0
	) {
	ObjectDelete(chartId, name);

	if (!ObjectCreate(chartId, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
		return false;

	ObjectSetInteger(chartId, name, OBJPROP_COLOR, rectColor);
	ObjectSetInteger(chartId, name, OBJPROP_STYLE, style);
	ObjectSetInteger(chartId, name, OBJPROP_WIDTH, width);
	ObjectSetInteger(chartId, name, OBJPROP_FILL, false);
	ObjectSetInteger(chartId, name, OBJPROP_BACK, false);
	ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
	ObjectSetInteger(chartId, name, OBJPROP_SELECTED, false);
	ObjectSetInteger(chartId, name, OBJPROP_HIDDEN, true);

	ChartRedraw(chartId);

	return ObjectFind(chartId, name) >= 0;
}

#endif
