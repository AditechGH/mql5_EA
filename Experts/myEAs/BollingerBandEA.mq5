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
static input long   inputMagicNumber    = 33333;                // magic number
input double        inputRiskPerTrade   = 1;                    // risk per trade
input int           inputPeriod         = 21;                   // period
input double        inputDeviation      = 2.0;                  // deviation
input int           inputStopLoss      = 100;                   // stop loss
input int           inputTakeProfit    = 200;                   // take profit (0=off)          

input group "==== Equity ===="
input int    inputMaxEquity     = 6;                       // stop out if profit reaches the percentage (100=off) 
input int    inputMinEquity     = 6;                       // stop out if loss reaches the percentage (100=off) 
input int    inputStartBalane   = 25000;                   // account balance
//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+

int handle;
double upperBuffer[];
double baseBuffer[];
double lowerBuffer[];
MqlTick currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

    // check user inputs
    if(!CheckInputs()) return INIT_PARAMETERS_INCORRECT;

    // set magic number to trade object
    trade.SetExpertMagicNumber(inputMagicNumber);

    // create indicator handle
    handle = iBands(_Symbol, PERIOD_CURRENT, inputPeriod, 1, inputDeviation, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) {
        Alert("Failed to create RSI indicator handle");
    }

    // set buffer as series
    ArraySetAsSeries(upperBuffer, true);
    ArraySetAsSeries(baseBuffer, true);
    ArraySetAsSeries(lowerBuffer, true);

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

   // release indicator handle
   if(handle != INVALID_HANDLE) IndicatorRelease(handle);
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {

    // check if current tick is a bar open tick
    if(!IsNewBar())  return;

    // Get current tick
    if(!SymbolInfoTick(_Symbol, currentTick)) {
        Print("Failed to get tick");
        return;
    }

     // get values indicator values
    int values = CopyBuffer(handle, 0, 0, 1, baseBuffer) 
               + CopyBuffer(handle, 1, 0, 1, upperBuffer) 
               + CopyBuffer(handle, 2, 0, 1, lowerBuffer);
    if(values != 3) {
        Print("Failed to get indicator values");
        return;
    }

    Comment("up[0]: ", upperBuffer[0], "\n",
        "base[1]: ", baseBuffer[0], "\n", 
        "lower[2]: " , lowerBuffer[0]);

     // count open positions
    int countBuy, countSell;
    if(!CountOpenPositions(countBuy, countSell)) return;

    // check for lower band cross to open a buy position
    if (countBuy == 0 && currentTick.ask <= lowerBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0)) {

        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
        double sl = currentTick.bid - inputStopLoss * _Point;
        double tp = inputTakeProfit == 0 ? 0 : currentTick.bid + inputTakeProfit * _Point;
        double pipPoints = (currentTick.ask - sl) / _Point;

        if(!NormalizePrice(sl, sl))  return;
        if(!NormalizePrice(tp, tp))   return;

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, CalculateLotSize(ORDER_TYPE_BUY, currentTick.ask, sl), currentTick.ask, sl, tp, "Bollinger band EA");
    }

    // check for upper band cross to open a buy position
    if (countSell == 0 && currentTick.bid >= upperBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0)) {

        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
        double sl = currentTick.ask + inputStopLoss * _Point;
        double tp = inputTakeProfit == 0 ? 0 : currentTick.bid - inputTakeProfit * _Point;
        double pipPoints = (sl - currentTick.bid) / _Point;

        if(!NormalizePrice(sl, sl))  return;
        if(!NormalizePrice(tp, tp))   return;

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, CalculateLotSize(ORDER_TYPE_SELL, currentTick.bid, sl), currentTick.bid, sl, tp, "Bollinger band EA");
    }

    // check for close at cross with base band
    if(!CountOpenPositions(countBuy, countSell)) return;
    if(countBuy > 0 && currentTick.bid >= baseBuffer[0]) ClosePositions(1);
    if(countBuy > 0 && currentTick.ask <= baseBuffer[0]) ClosePositions(2);
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

// check user inputs
bool CheckInputs() {
    if(inputMagicNumber <= 0) {
        Alert("Magic Number is less than zero");
        return false;
    }
    if(inputStopLoss <= 0) {
      Alert("Stop loss <= 0");
      return false;
    }
    if(inputTakeProfit < 0) {
      Alert("Take Profit < 0");
      return false;
    }
    if(inputPeriod <= 0) {
      Alert("Period <= 0");
      return false;
    }
    if(inputDeviation <= 0) {
      Alert("Deviation <= 0");
      return false;
    }
    return true;
}

// check if we have a bar open tick
bool IsNewBar() {
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(previousTime != currentTime) {
      previousTime = currentTime;
      return true;
   }
   return false;
}

// count open positions
bool CountOpenPositions(int &countBuy, int &countSell) {

   countBuy = 0;
   countSell = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0) {
         Print("Failed to get ticket");
         return false;
      }
      if(!PositionSelectByTicket(ticket)) {
         Print("Failed to select position");
         return false;
      }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)) {
         Print("Failed to get position magic number");
         return false;
      }
      if(magic == inputMagicNumber) {
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) {
            Print("Failed to get position type");
            return false;
         }
         if(type == POSITION_TYPE_BUY) countBuy++;
         if(type == POSITION_TYPE_SELL) countSell++;
      }
   }
   return true;
} 

// calculate for lot size based on the account balance and risk per trade
double CalculateLotSize(ENUM_ORDER_TYPE type, double ask, double pipPoints) {

    double maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * inputRiskPerTrade / 100;
    double riskPerPip = maxRiskAmount / (pipPoints / 10);
 
    double pipValue = 10 * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskPerPip / pipValue;  
    
    double minLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLotSize = (AccountInfoDouble(ACCOUNT_BALANCE) * AccountInfoInteger(ACCOUNT_LEVERAGE)) / 
                        SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

    if ( lotSize < minLotSize ) lotSize = minLotSize;
    if ( lotSize > maxLotSize ) lotSize = maxLotSize;

    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double margin = 0.0;
    if(!OrderCalcMargin(type, _Symbol, lotSize, ask, margin)) {
        Print("Margin Calculation Error");
        return NormalizeDouble(minLotSize, 2);
    }
    
    if(freeMargin - margin <= 0.0) {
       double m = (margin * AccountInfoInteger(ACCOUNT_LEVERAGE)) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
       lotSize = lotSize - (m - lotSize);
    }
     
    return NormalizeDouble(lotSize, 2);
}

// equity stop out
bool EquityStopOut () {
    double diff = AccountInfoDouble(ACCOUNT_BALANCE) - inputStartBalane;
    double percentile = (MathAbs(diff) * 100) / inputStartBalane;
    return ( (diff > 0 && percentile >= inputMaxEquity) || (diff < 0 && percentile >= inputMinEquity));
}

// normalize price
bool NormalizePrice(double price, double &normalizedprice) {

   double tickSize = 0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tickSize)) {
      Print("Failed to get tick size");
      return false;
   }
   normalizedprice = NormalizeDouble(MathRound(price/tickSize) * tickSize, _Digits);
   
   return true;
}


// close positions
bool ClosePositions(int all_buy_sell) {

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0) {
         Print("Failed to get ticket");
         return false;
      }
       if(!PositionSelectByTicket(ticket)) {
         Print("Failed to select position");
         return false;
      }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)) {
         Print("Failed to get position magic number");
         return false;
      }
      if(magic == inputMagicNumber) {
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) {
            Print("Failed to get position type");
            return false;
         }
         if(all_buy_sell == 1 && type == POSITION_TYPE_SELL) continue;
         if(all_buy_sell == 2 && type == POSITION_TYPE_BUY) continue;
         trade.PositionClose(ticket);
         if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
            Print("Failed to close position. ticket: ", (string)ticket, " result: ", (string)trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
            return false;
         }
      }
   }
   return true;
}