#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input int inputFastPeriod = 14;    // fast period
input int inputSlowPeriod = 21;    // slow period
input int inputStopLoss = 100;     // stop loss in points
input int inputTakeProfit = 200;   // take profit in points

//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+
int fastHandle;
int slowHandle;
double fastBuffer[];
double slowBuffer[];
datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

   // check user input
   if(inputFastPeriod <= 0) {
    Alert("Fast period is less than zero");
    return INIT_PARAMETERS_INCORRECT;
   }
   if(inputSlowPeriod <= 0) {
    Alert("Slow period is less than zero");
    return INIT_PARAMETERS_INCORRECT;
   }
   if(inputSlowPeriod <= inputFastPeriod) {
    Alert("Slow period cannot be less than or equal to fast period");
    return INIT_PARAMETERS_INCORRECT;
   }
   if(inputStopLoss <= 0) {
    Alert("Stop loss is less than zero");
    return INIT_PARAMETERS_INCORRECT;
   }
   if(inputTakeProfit <= 0) {
    Alert("Take profit is less than zero");
    return INIT_PARAMETERS_INCORRECT;
   }
   
   // create handles
   fastHandle = iMA(_Symbol, PERIOD_CURRENT, inputFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(fastHandle == INVALID_HANDLE) {
      Alert("Failed to create fast handle");
      return INIT_FAILED;
   }
   slowHandle = iMA(_Symbol, PERIOD_CURRENT, inputSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(slowHandle == INVALID_HANDLE) {
      Alert("Failed to create slow handle");
      return INIT_FAILED;
   }
   
   // set buffer
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

   // remove handles
   if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {

   // get indicator values
   int values = CopyBuffer(fastHandle, 0, 0, 2, fastBuffer);
   if(values != 2) {
     Print("Not enough data for fast moving average");
     return;
   }
   values = CopyBuffer(slowHandle, 0, 0, 2, slowBuffer);
   if(values != 2) {
     Print("Not enough data for slow moving average");
     return;
   }
   
   Comment("Fast[0]: ", fastBuffer[0], "\n",
           "Fast[1]: ", fastBuffer[1], "\n", 
           "Slow[0]: ", slowBuffer[0], "\n",
           "Slow[1]: ", slowBuffer[1]);
   
   
   // check for cross buy
   if (fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0)) {
   
      openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
      double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl   = ask - inputStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp   = ask + inputTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, 1.0, ask, sl, tp, "Cross EA");
   }
   
     // check for cross sell
   if (fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0)) {
   
      openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl    = bid + inputStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp    = bid - inputTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, 1.0, bid, sl, tp, "Cross EA");
   }
}
