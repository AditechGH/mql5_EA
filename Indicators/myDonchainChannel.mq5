#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+

input int   inputPeriod   = 20;         // period
input int   inputOffset   = 0;          // offset in % of channel
input color inputUpperColor   = clrGreen;   // color
input color inputLowerColor   = clrRed;   // color

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

double bufferUpper[];
double bufferLower[];
double upper, lower;
int first, bar;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {

  // initialize buffers
  InitializeBuffer(0, bufferUpper, inputUpperColor, "Donchain Upper");
  InitializeBuffer(1, bufferLower, inputLowerColor, "Donchain Lower");
  IndicatorSetString(INDICATOR_SHORTNAME, "Donchain("+IntegerToString(inputPeriod)+")");

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{

  if (rates_total < inputPeriod + 1) return 0;

  first = prev_calculated == 0 ? inputPeriod : prev_calculated - 1;

  for(bar = first; bar < rates_total; bar++) {

      upper = open[ArrayMaximum(open, bar - inputPeriod + 1, inputPeriod)];
      lower = open[ArrayMinimum(open, bar - inputPeriod + 1, inputPeriod)];

      bufferUpper[bar] = upper - (upper - lower) * inputOffset * 0.01;
      bufferLower[bar] = lower + (upper - lower) * inputOffset * 0.01;
  }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

void InitializeBuffer(int index, double &buffer[], color bufferColor, string label) {

    SetIndexBuffer(index, buffer, INDICATOR_DATA);
    PlotIndexSetInteger(index, PLOT_DRAW_TYPE, DRAW_LINE);
    PlotIndexSetInteger(index, PLOT_LINE_WIDTH, 2);
    PlotIndexSetInteger(index, PLOT_DRAW_BEGIN, inputPeriod - 1);
    PlotIndexSetInteger(index, PLOT_SHIFT, 1);
    PlotIndexSetInteger(index, PLOT_LINE_COLOR, bufferColor);
    PlotIndexSetString(index, PLOT_LABEL, label);
    PlotIndexSetDouble(index, PLOT_EMPTY_VALUE, EMPTY_VALUE);
}