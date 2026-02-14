#ifndef __H_DRAW_HORIZONTAL_LINE_MQH__
#define __H_DRAW_HORIZONTAL_LINE_MQH__

bool DrawHorizontalLine(
	string name,
	double price,
	color lineColor = clrWhite,
	ENUM_LINE_STYLE style = STYLE_SOLID,
	int width = 1,
	long chartId = 0
) {
	ObjectDelete(chartId, name);

	if (!ObjectCreate(chartId, name, OBJ_HLINE, 0, 0, price))
		return false;

	ObjectSetInteger(chartId, name, OBJPROP_COLOR, lineColor);
	ObjectSetInteger(chartId, name, OBJPROP_STYLE, style);
	ObjectSetInteger(chartId, name, OBJPROP_WIDTH, width);
	ObjectSetInteger(chartId, name, OBJPROP_BACK, false);
	ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
	ObjectSetInteger(chartId, name, OBJPROP_SELECTED, false);
	ObjectSetInteger(chartId, name, OBJPROP_HIDDEN, true);

	ChartRedraw(chartId);

	return ObjectFind(chartId, name) >= 0;
}

#endif
