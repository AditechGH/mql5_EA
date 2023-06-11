#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

#define FIBO_OBJ "Fibo Retracement"

#include <Trade/Trade.mqh>

input double Lots = 0.1;
input double RetracementLevel = 61.8;
input double SlPoints = 200;
input double TpPoints = 200;
input int    ExpirationHours = 15;

int barsTotal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

    int bars = iBars(_Symbol, PERIOD_D1);
    if(barsTotal != bars && TimeCurrent() > StringToTime("00:05")) {
        barsTotal = bars;

        ObjectDelete(0, FIBO_OBJ);

        double open = iOpen(_Symbol, PERIOD_D1, 1);
        double close = iClose(_Symbol, PERIOD_D1, 1);
        double high = iHigh(_Symbol, PERIOD_D1, 1);
        double low  = iLow(_Symbol, PERIOD_D1, 1);

        datetime time_start = iTime(_Symbol, PERIOD_D1, 1);
        datetime time_end = iTime(_Symbol, PERIOD_D1, 0) - 1;

        datetime expiration = iTime(_Symbol, PERIOD_D1, 0) + ExpirationHours * PeriodSeconds(PERIOD_D1);

        double entryLevel;
        if(close > open) {
            ObjectCreate(0, FIBO_OBJ, OBJ_FIBO, 0, time_start, low, time_end, high);
            entryLevel = high - (high - low) * RetracementLevel / 100;
            double  entry = NormalizeDouble(entryLevel, _Digits);

            double sl = entry - SlPoints * _Point;

            double tp = entry + TpPoints * _Point;

            CTrade trade;
            if(trade.BuyLimit(Lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, "")) {
                Print(__FUNCTION__, " > Buy order sent...");
            }; 

        } else {
            ObjectCreate(0, FIBO_OBJ, OBJ_FIBO, 0, time_start, high, time_end, low);
            entryLevel = low + (high - low) * RetracementLevel / 100;
            double  entry = NormalizeDouble(entryLevel, _Digits);

            double sl = entry - SlPoints * _Point;

            double tp = entry + TpPoints * _Point;

            CTrade trade;
            if(trade.SellLimit(Lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, "")) {
                Print(__FUNCTION__, " > Buy order sent...");
            }
        }
       
        ObjectSetInteger(0, FIBO_OBJ, OBJPROP_COLOR, clrBlack);

        color fiboClrs[] = {clrGray, clrRed, clrYellow, clrGreen, clrLightGreen, clrCyan, clrGray, clrBlue, clrRed, clrViolet, clrIndianRed};
        for(int i = 0; i < ObjectGetInteger(0, FIBO_OBJ, OBJPROP_LEVELS); i++) {
            ObjectSetInteger(0, FIBO_OBJ, OBJPROP_LEVELCOLOR, fiboClrs[i]);
        }
    }
}
