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
static input long     inputMagicNumber = 11111;     // magic number
static input double   inputLotSize     = 0.01;      // lot size
input int             inputRSIPeriod   = 21;        // rsi priod
input int             inputRSILevel    = 70;        // rsi level (upper)
input int             inputMAPeriod    = 21;        // ma period
input ENUM_TIMEFRAMES inputMATimeframe = PERIOD_H1; // ma timeframe
input int             inputStopLoss    = 100;       // stop loss in points (0=off)
input int             inputTakeProfit  = 200;       // take profit in points (0=off)
input bool            inputCloseSignal = false;     // close tades by opposite signal 

//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+
int handleRSI;
int handleMA;
double bufferRSI[];
double bufferMA[];
MqlTick currentTick;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

   // check user input
   if(inputMagicNumber <= 0) {
      Alert("Magic Number is less than zero");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputLotSize <= 0 || inputLotSize > 10) {
      Alert("Lot size must be more than 0 and less than 10");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputRSIPeriod <= 1) {
      Alert("RSI period must be less than or equal to 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputRSILevel >= 100 || inputRSILevel <= 50) {
      Alert("input RSI level must be greater than/equal to 100 or less than/equal to 50");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputMAPeriod <= 1) {
      Alert("MA period must be less than or equal to 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputStopLoss < 0) {
      Alert("Stop loss is less than zero");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputTakeProfit < 0) {
      Alert("Take profit is less than zero");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // set magic number to trade object
   trade.SetExpertMagicNumber(inputMagicNumber);
   
   // create indicator handles
   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, inputRSIPeriod, PRICE_OPEN);
   if(handleRSI == INVALID_HANDLE) {
      Alert("Failed to create RSI indicator handle");
   }
   handleMA = iMA(_Symbol, inputMATimeframe, inputMAPeriod,0, MODE_SMA, PRICE_OPEN);
   if(handleMA == INVALID_HANDLE) {
      Alert("Failed to create MA indicator handle");
   }
   
   // set buffer as series
   ArraySetAsSeries(bufferRSI, true);
   ArraySetAsSeries(bufferMA, true);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

   // release indicator handles
   if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
   if(handleMA != INVALID_HANDLE) IndicatorRelease(handleMA);
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

   // check if current tick is a new bar open tick
   if(!IsNewBar()) {
      return;
   }

   // get current tick
   if(!SymbolInfoTick(_Symbol, currentTick)) {
      Print("Failed to get current tick");
      return;
   }
   
   // get values indicator values
   int values = CopyBuffer(handleRSI, 0, 0, 2, bufferRSI);
   if(values != 2) {
      Print("Failed to get RSI indicator values");
      return;
   }
   values = CopyBuffer(handleMA, 0, 0, 1, bufferMA);
   if(values != 1) {
      Print("Failed to get MA indicator value");
      return;
   }
   
   
    Comment("BufferRSI[0]: ", bufferRSI[0], "\n",
            "BufferRSI[1]: ", bufferRSI[1], "\n", 
            "BufferMA[0]: " , bufferMA[0]);
            
    // count open positions
    int countBuy, countSell;
    if(!CountOpenPositions(countBuy, countSell)) return;
    
    // check for buy position
    if(countBuy == 0 && bufferRSI[1] >= (100 - inputRSILevel) && bufferRSI[0] < (100 - inputRSILevel) && currentTick.ask > bufferMA[0]) {
    
      if(inputCloseSignal) {
         if(!ClosePositions(2)) {
            return;
         }
      }
      double sl = inputStopLoss == 0 ? 0 : currentTick.bid - inputStopLoss * _Point;
      double tp = inputTakeProfit == 0 ? 0 : currentTick.bid + inputTakeProfit * _Point;
      if(!NormalizePrice(sl)) {
         return;
      }
      if(!NormalizePrice(tp)) {
         return;
      }
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, inputLotSize, currentTick.ask, sl, tp, "RSI-MA EA");
    }
    
    // check for sell position
    if(countSell == 0 && bufferRSI[1] <= inputRSILevel && bufferRSI[0] > inputRSILevel && currentTick.bid < bufferMA[0]) {
    
      if(inputCloseSignal) {
         if(!ClosePositions(1)) {
            return;
         }
      }
      double sl = inputStopLoss == 0 ? 0 : currentTick.ask + inputStopLoss * _Point;
      double tp = inputTakeProfit == 0 ? 0 : currentTick.ask - inputTakeProfit * _Point;
      if(!NormalizePrice(sl)) {
         return;
      }
      if(!NormalizePrice(tp)) {
         return;
      }
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, inputLotSize, currentTick.bid, sl, tp, "RSI-MA EA");
    }
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

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

// normalize price
bool NormalizePrice(double &price) {

   double tickSize = 0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tickSize)) {
      Print("Failed to get tick size");
      return false;
   }
   price = NormalizeDouble(MathRound(price/tickSize) * tickSize, _Digits);
   
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
