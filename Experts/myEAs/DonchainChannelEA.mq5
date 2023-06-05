#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Defines                                                          |
//+------------------------------------------------------------------+

#define INDICATOR_NAME "myDonchainChannel"

//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input group "==== General Inputs ====";
static input long     inputMagicNumber = 866667;          // magic number
static input double   inputLotSize     = 0.01;            // lot size
enum SL_TP_MODE_ENUM{
    SL_TP_MODE_PCT,                                       // sl/tp in %
    SL_TP_MODE_POINTS                                     // sl/tp in points
};
input SL_TP_MODE_ENUM inputSLTPMode    = SL_TP_MODE_PCT;  // sl/tp mode 
input int             inputStopLoss    = 200;             // stop loss in points (0=off)
input int             inputTakeProfit  = 175;             // take profit in points (0=off)
input bool            inputCloseSignal = true;            // close tades by opposite signal 
input int             inputSizeFilter  = 325;             // size filter in points (0=off)           

input group "==== Donachain channel ===="; 
input int             inputPeriod       = 100;            // period
input int             inputOffset       = 40;             // offset in % of channel (0 - 49%)
input color           inputUpperColor   = clrGreen;     // color
input color           inputLowerColor   = clrRed;       // color

//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+
int handle;
double bufferUpper[];
double bufferLower[];
MqlTick currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

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
   if(inputStopLoss < 0) {
      Alert("Stop loss is less than zero");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputTakeProfit < 0) {
      Alert("Take profit is less than zero");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputStopLoss == 0 && !inputCloseSignal) {
      Alert("No stop loss and no close signal");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputSizeFilter < 0) {
      Alert("size filter < 0");
      return INIT_PARAMETERS_INCORRECT;
   }

  if(inputPeriod <= 1) {
      Alert("Donchain channel must be less than or equal to 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(inputOffset < 0 || inputOffset >= 50) {
      Alert("Donchain channel offset < 0 or >= 50");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // set magic number to trade object
   trade.SetExpertMagicNumber(inputMagicNumber);
   
   // create indicator handles
   handle = iCustom(_Symbol, PERIOD_CURRENT, INDICATOR_NAME, inputPeriod, inputOffset, inputUpperColor);
   if(handle == INVALID_HANDLE) {
      Alert("Failed to create indicator handle");
   }
   
   // set buffer as series
   ArraySetAsSeries(bufferLower, true);
   ArraySetAsSeries(bufferUpper, true);

   // draw indicator on chart
   ChartIndicatorDelete(NULL, 0, "Donchain("+IntegerToString(inputPeriod)+")");
   ChartIndicatorAdd(NULL, 0, handle);

   return(INIT_SUCCEEDED); 
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

   // release indicator handles
   if(handle != INVALID_HANDLE) {
    ChartIndicatorDelete(NULL, 0, "Donchain("+IntegerToString(inputPeriod)+")");
    IndicatorRelease(handle);
   }
   
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
   int values = CopyBuffer(handle, 0, 0, 1, bufferUpper) + CopyBuffer(handle, 1, 0, 1, bufferLower);
   if(values != 2) {
      Print("Failed to get indicator values");
      return;
   }
   
   
    // Comment("BufferUpper[0]: ", bufferUpper[0], "\n",
    //        "BufferLower[1]: ", bufferLower[1], "\n");
            
    // count open positions
    int countBuy, countSell;
    if(!CountOpenPositions(countBuy, countSell)) return;

    // check size filter
    if (inputSizeFilter > 0 && (bufferUpper[0] - bufferUpper[0]) < inputSizeFilter * _Point) { return; }
    
    // check for buy position
    if(countBuy == 0 && currentTick.ask <= bufferLower[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0)) {
    

        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
        if(inputCloseSignal) {
            if(!ClosePositions(2)) {
                return;
            }
        }
        double sl = 0;
        double tp = 0;
        if(inputSLTPMode == SL_TP_MODE_PCT) {
            sl = inputStopLoss == 0 ? 0 : currentTick.bid - (bufferUpper[0] - bufferLower[0]) *inputStopLoss * 0.01;
            tp = inputTakeProfit == 0 ? 0 : currentTick.bid + (bufferUpper[0] - bufferLower[0]) * inputTakeProfit * 0.01;
        } else {
            sl = inputStopLoss == 0 ? 0 : currentTick.bid - inputStopLoss * _Point;
            tp = inputTakeProfit == 0 ? 0 : currentTick.bid + inputTakeProfit * _Point;
        }
        if(!NormalizePrice(sl)) {
            return;
        }
        if(!NormalizePrice(tp)) {
            return;
        }
        
        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, inputLotSize, currentTick.ask, sl, tp, "Donchain channel EA");
    }
    
        // check for sell position
        if(countSell == 0 && currentTick.bid >= bufferUpper[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0)) {
        
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
        if(inputCloseSignal) {
            if(!ClosePositions(1)) {
                return;
            }
        }
        double sl = 0;
        double tp = 0;
        if(inputSLTPMode == SL_TP_MODE_PCT) {
            sl = inputStopLoss == 0 ? 0 : currentTick.ask + (bufferUpper[0] - bufferLower[0]) *inputStopLoss * 0.01;
            tp = inputTakeProfit == 0 ? 0 : currentTick.ask - (bufferUpper[0] - bufferLower[0]) * inputTakeProfit * 0.01;
        } else {
            sl = inputStopLoss == 0 ? 0 : currentTick.ask + inputStopLoss * _Point;
            tp = inputTakeProfit == 0 ? 0 : currentTick.ask - inputTakeProfit * _Point;
        }
        if(!NormalizePrice(sl)) {
            return;
        }
        if(!NormalizePrice(tp)) {
            return;
        }
        
        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, inputLotSize, currentTick.bid, sl, tp, "Donchain channel EA");
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