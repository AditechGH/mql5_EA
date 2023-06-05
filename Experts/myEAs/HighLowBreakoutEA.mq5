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
input group "==== General Inputs ===="
static input long   inputMagicNumber   = 1440563;       // magic  
static input double inputLotSize       = 1;             // lot size
input int           inputBars          = 150;           // stop loss in % of the range (0=off)
input int           inputIndexFilter   = 0;             // index filter in % (0=off) 
input int           inputSizeFilter    = 800;           // size filter in points (0=off) 
input int           inputStopLoss      = 150;           // stop loss in points
input bool          inputTrailingSL    = true;          // trailing stop loss?
input int           inputTakeProfit    = 0;             // take profit in % of the range (0=off)


// bar - (start->50, step->50, stop->200)
// size filter - (start->0, step->200, stop->1400)
// stop loss - (start->200, step->50, stop->300)
//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+

double high = 0;    // hightest price of the last N bar
double low  = 0;    // lowest price of the last N bar
int highIdx = 0;    // index of highest bar  
int lowIdx  = 0;    // index of highest bar  
MqlTick previousTick, currentTick;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

    // check user inputs
    if(!CheckInputs()) return INIT_PARAMETERS_INCORRECT;

    // set magic number to trade object
    trade.SetExpertMagicNumber(inputMagicNumber);

    Print("SYMBOL_POINT: ", SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    Print("tickSize: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
    Print("volume_step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

    ObjectDelete(NULL, "high");
    ObjectDelete(NULL, "low");
    ObjectDelete(NULL, "text");
    ObjectDelete(NULL, "indexFilter");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

    // check if current tick is a new bar open tick
    if(!IsNewBar()) { return; }
 
    // get tick
    previousTick = currentTick;
    if(!SymbolInfoTick(_Symbol, currentTick)) { Print("Failed to get currrent tick"); return; }

    // count open positions
    int countBuy, countSell;
    if(!CountOpenPositions(countBuy, countSell)) { return; }


    // check for buy position
    if(countBuy == 0 && high != 0 && previousTick.ask < high && currentTick.ask >= high && CheckIndexFilter(highIdx) && CheckSizeFilter()) {

        // calculate stop loss / take profit
        double sl = currentTick.bid - inputStopLoss * _Point;
        double tp = inputTakeProfit == 0 ? 0 : currentTick.bid + inputTakeProfit * _Point;
        if(!NormalizePrice(sl)) { return; }
        if(!NormalizePrice(tp)) { return; }
        
        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, inputLotSize, currentTick.ask, sl, tp, "HighLowBreakout EA");
    }
    
    // check for sell position
    if(countSell == 0 && low != 0 && previousTick.bid > low && currentTick.bid <= low  && CheckIndexFilter(lowIdx) && CheckSizeFilter()) {

        // calculate stop loss / take profit
        double sl = currentTick.ask + inputStopLoss * _Point;
        double tp = inputTakeProfit == 0 ? 0 : currentTick.ask - inputTakeProfit * _Point;
        if(!NormalizePrice(sl)) { return; }
        if(!NormalizePrice(tp)) { return; }
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, inputLotSize, currentTick.bid, sl, tp, "HighLowBreakout EA");
    }

    // update stop loss
    if(inputTrailingSL) {
        UpdateStopLoss(inputStopLoss * _Point);
    }

    // calculate high/low
    highIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, inputBars, 1);
    lowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, inputBars, 1);
    high = iHigh(_Symbol, PERIOD_CURRENT, highIdx);
    low = iLow(_Symbol, PERIOD_CURRENT, lowIdx);

    DrawObjects();
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

// check user inputs
bool CheckInputs() {
    if(inputMagicNumber <= 0) {
        Alert("Wrong input: MagicNumber <= 0");
        return false;
    }
    if(inputStopLoss <= 0) {
        Alert("Wrong input: Stop loss  <= 0");
        return false;
    }
    if(inputTakeProfit < 0) {
        Alert("Wrong input: Take Profit < 0");
        return false;
    }
    if(inputBars <= 0) {
        Alert("Wrong input: Bars <= 0");
        return false;
    }
    if(inputIndexFilter < 0 || inputIndexFilter >= 50) {
        Alert("Wrong input: Index filter < 0 or >= 50");
        return false;
    }
    if(inputSizeFilter < 0) {
        Alert("Wrong input: input filter < 0");
        return false;
   }
    if(inputLotSize <= 0) {
        Alert("Wrong input: Lot Size <= 0");
        return false;
    }
    return true;
}

// check if high/low is inside valid index range
bool CheckIndexFilter(int index) {

    if(inputIndexFilter > 0 && (index <= round(inputBars * inputIndexFilter * 0.01) || index > inputBars - round(inputBars * inputIndexFilter * 0.01))) {
        return false;
    }
    return true;
}

// check channel size
bool CheckSizeFilter() {

    if(inputIndexFilter > 0 && (high - low) > inputSizeFilter * _Point) {
        return false;
    }
    return true;
}

// count open positions
bool CountOpenPositions(int &countBuy, int &countSell) {

   countBuy = 0;
   countSell = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) {

      ulong ticket = PositionGetTicket(i);
      
      if(ticket<=0) { Print("Failed to get ticket"); return false; }
      if(!PositionSelectByTicket(ticket)) { Print("Failed to select position"); return false; }

      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)) { Print("Failed to get position magic number"); return false; }

      if(magic == inputMagicNumber) {
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) { Print("Failed to get position type"); return false; }
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

// draw lines on chart
void DrawObjects() {

    datetime time1 = iTime(_Symbol, PERIOD_CURRENT, inputBars);
    datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 1);

    // high
    ObjectDelete(NULL, "high");
    ObjectCreate(NULL, "high", OBJ_TREND, 0, time1, high, time2, high);
    ObjectSetInteger(NULL, "high", OBJPROP_WIDTH, 3);
    ObjectSetInteger(NULL, "high", OBJPROP_COLOR, CheckIndexFilter(highIdx) && CheckSizeFilter() ? clrLime : clrBlue);

     // low
    ObjectDelete(NULL, "low");
    ObjectCreate(NULL, "low", OBJ_TREND, 0, time1, low, time2, low);
    ObjectSetInteger(NULL, "low", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "low", OBJPROP_COLOR, CheckIndexFilter(highIdx) && CheckSizeFilter() ? clrLime : clrBlue);

    // index filter
    ObjectDelete(NULL, "indexFilter");
    if(inputIndexFilter > 0) {
        datetime time1IF1 = iTime(_Symbol, PERIOD_CURRENT, (int) (inputBars - round(inputBars * inputIndexFilter * 0.01)));
        datetime time1IF2 = iTime(_Symbol, PERIOD_CURRENT, (int) round(inputBars * inputIndexFilter * 0.01));

        ObjectCreate(NULL, "indexFilter", OBJ_RECTANGLE, 0, time1IF1, low, time1IF2, high);
        ObjectSetInteger(NULL, "indexFilter", OBJPROP_BACK, true);
        ObjectSetInteger(NULL, "indexFilter", OBJPROP_FILL, true);
        ObjectSetInteger(NULL, "indexFilter", OBJPROP_COLOR,clrBrown);
    }

    // text
    ObjectDelete(NULL, "text");
    ObjectCreate(NULL, "text", OBJ_TEXT, 0, time2, low);
    ObjectSetInteger(NULL, "text", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetInteger(NULL, "text", OBJPROP_COLOR, clrBlueViolet);
    ObjectSetString(NULL, "text", OBJPROP_TEXT, "Bars:" + (string) inputBars + " index filter:" + DoubleToString(round(inputBars * inputIndexFilter * 0.01), 0)
                                            + " high index: " + (string) highIdx + " low index:" +(string)lowIdx +
                                            " size:" + DoubleToString( (high - low) / _Point));


    // refresh chart
    // ChartRedraw();
}

// update stop loss
void UpdateStopLoss (double slDistance) {

    // loop though open positions
    int total = PositionsTotal();
    for(int i = total - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) {  Print("Failed to get position ticket");  return;  }
        if(!PositionSelectByTicket(ticket)) {  Print("Failed to select position");  return;  }

        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic)) {   Print("Failed to get position magic number");  return; }
        if(magic == inputMagicNumber) {
            long type;
            if(!PositionGetInteger(POSITION_TYPE, type)) {  Print("Failed to get position type");  return;  }
            double currSL, currTP;
            if(!PositionGetDouble(POSITION_SL, currSL)) { Print("Failed to get position stop loss"); return; }
            if(!PositionGetDouble(POSITION_TP, currTP)) { Print("Failed to get position take profit"); return; }

            // calculate stop loss
            double currentPrice = type == POSITION_TYPE_BUY ? currentTick.bid : currentTick.ask; 
            int n               = type == POSITION_TYPE_BUY ? 1 : -1;
            double newSL        = currentPrice - slDistance * n; 
            if (!NormalizePrice(newSL)) { return; }  

            // check if new stop loss is closer to current price than existing stop loss
            if((newSL * n) < (currSL * n) || NormalizeDouble(MathAbs(newSL - currSL), _Digits) < _Point) {
                // Print("No new stop loss needed");
                continue;
            } 

            // check for stop level
            long level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            if(level != 0 && MathAbs(currentPrice-newSL) <= level * _Point) {
                Print("New stop loss inside stop level");
            }

            // modify position with new stop loss
            if(!trade.PositionModify(ticket, newSL, currTP)) {
                 Print("Failed to modify position, ticket: ", (string) ticket, " currSL: ", (string) currSL, 
                   " newSL: ", (string) newSL, " currTP: ", (string) currTP);
                return;   
            }
        }
   }
}
