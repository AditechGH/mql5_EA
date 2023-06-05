#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Defines                                                          |
//+------------------------------------------------------------------+
#define NR_CONDITIONS 2      // number of conditions

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+
enum MODE{
    OPEN=0,     // open
    HIGH=1,     // high
    LOW=2,      // low
    CLOSE=3,    // close
    RANGE=4,    // range (points)
    BODY=5,     // body (points)
    RATIO=6,    // ratio (body/range)
    VALUE=7     // value
};

enum INDEX{
    INDEX_0=0,  // index 0
    INDEX_1=1,  // index 1
    INDEX_2=2,  // index 2
    INDEX_3=3,  // index 3
};

enum COMPARE{
    GREATER,    // greater
    LESS,       // less
};

struct CONDITION {
    bool active;    // condition active?
    MODE modeA;     // mode A
    INDEX idxA;     // index A
    COMPARE comp;   // compare
    MODE modeB;     // mode B
    INDEX idxB;     // index B
    double value;   // value

    CONDITION(): active(false){};
};

CONDITION con[NR_CONDITIONS];   // condition array
MqlTick currentTick;            // current tick of the symbil
CTrade trade;                   // object to open/close position

//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input group "==== General Inputs ===="
static input long   inputMagicNumber   = 5456763;       // magic  
static input double inputLotSize       = 0.01;          // lot size
input int           inputStopLoss      = 100;           // stop loss in points (0=off)
input int           inputTakeProfit    = 200;           // take profit in % of the range (0=off)

input group "==== Conditon 1 ====";
input  bool inputCon1ctive    = false;      // active
input  MODE inputCon1ModeA    = OPEN;       // mode A
input  INDEX inputCon1IdxA    = INDEX_1;    // index A
input  COMPARE inputCon1Comp  = GREATER;    // compare
input  MODE inputCon1ModeB    = CLOSE;      // mode B
input  INDEX inputCon1IdxB    = INDEX_1;    // index B
input  double inputCon1Value  = 0;          // value

input group "==== Conditon 2 ====";
input  bool inputCon2ctive    = false;      // active
input  MODE inputCon2ModeA    = OPEN;       // mode A
input  INDEX inputCon2IdxA    = INDEX_1;    // index A
input  COMPARE inputCon2Comp  = GREATER;    // compare
input  MODE inputCon2ModeB    = CLOSE;      // mode B
input  INDEX inputCon2IdxB    = INDEX_1;    // index B
input  double inputCon2Value  = 0;          // value



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

    // set inputs (before we check inputs)
    SetInputs();

    // check user inputs
    if(!CheckInputs()) return INIT_PARAMETERS_INCORRECT;

    // set magic number to trade object
    trade.SetExpertMagicNumber(inputMagicNumber);

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
   // check if current tick is a new bar open tick
   if(!IsNewBar()) { return; }

   // get current symbol tick
    if(!SymbolInfoTick(_Symbol, currentTick)) { Print("Failed to get currrent tick"); return; }

    // count open positions
    int countBuy, countSell;
    if(!CountOpenPositions(countBuy, countSell)) { Print("Failed to count open positions"); return; }

    // check for new buy position
    if (countBuy == 0 && CheckAllConditions(true)) {

        // calculate stop loss and take profit
        double sl = inputStopLoss == 0 ? 0 : currentTick.bid - inputStopLoss * _Point;
        double tp = inputTakeProfit == 0 ? 0 : currentTick.bid + inputTakeProfit * _Point;
        if(!NormalizePrice(sl)) { return; }
        if(!NormalizePrice(tp)) { return; }

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, inputLotSize, currentTick.ask, sl, tp, "CandlePattern EA");
    } 

    // check for new sell position
    if (countSell == 0 && CheckAllConditions(false)) {

        // calculate stop loss and take profit
        double sl = inputStopLoss == 0 ? 0 : currentTick.ask + inputStopLoss * _Point;
        double tp = inputTakeProfit == 0 ? 0 : currentTick.ask - inputTakeProfit * _Point;
        if(!NormalizePrice(sl)) { return; }
        if(!NormalizePrice(tp)) { return; }

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, inputLotSize, currentTick.bid, sl, tp, "CandlePattern EA");
    } 
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
void SetInputs() {

    // condition 1
    con[0].active       = inputCon1ctive;
    con[0].modeA        = inputCon1ModeA;
    con[0].idxA         = inputCon1IdxA;
    con[0].comp         = inputCon1Comp;
    con[0].modeB        = inputCon1ModeB;
    con[0].idxB         = inputCon1IdxB;
    con[0].value        = inputCon1Value;

    // condition 2
    con[1].active       = inputCon2ctive;
    con[1].modeA        = inputCon2ModeA;
    con[1].idxA         = inputCon2IdxA;
    con[1].comp         = inputCon2Comp;
    con[1].modeB        = inputCon2ModeB;
    con[1].idxB         = inputCon2IdxB;
    con[1].value        = inputCon2Value;

}

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
    if(inputLotSize <= 0) {
        Alert("Wrong input: Lot Size <= 0");
        return false;
    }

    // check conditions
    return true;
}

bool CheckAllConditions(bool buy_sell) {

    // check each condition
    for (int i = 0; i < NR_CONDITIONS; i++) {
        if(!CheckOneCondition(buy_sell, i)) { return false; }
    }

    return true;
}

bool CheckOneCondition (bool buy_sell, int idx) {

    // return true if condition is not active
    if(!con[idx].active) { return true; }

    // get bar data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 4, rates);
    if(copied != 4) {
        Print("Failed to get bar data. copied:", (string) copied);
    }

    // set values to a and b
    double a = 0;
    double b = 0;
    switch (con[idx].modeA)  {
        case OPEN:  a = rates[con[idx].idxA].open; break;
        case HIGH:  a = buy_sell ? rates[con[idx].idxA].high : rates[con[idx].idxA].low; break;
        case LOW:   a = buy_sell ? rates[con[idx].idxA].low : rates[con[idx].idxA].high; break;
        case CLOSE: a = rates[con[idx].idxA].close; break;   
        case RANGE: a = (rates[con[idx].idxA].high - rates[con[idx].idxA].low) / _Point; break;   
        case BODY:  a = MathAbs(rates[con[idx].idxA].open - rates[con[idx].idxA].close) / _Point; break;
        case RATIO: a = MathAbs(rates[con[idx].idxA].open - rates[con[idx].idxA].close) / 
                        (rates[con[idx].idxA].high - rates[con[idx].idxA].low); break;
        case VALUE: a = con[idx].value; break;
        default: return false;
    }
    switch (con[idx].modeB)  {
        case OPEN:  b = rates[con[idx].idxB].open; break;
        case HIGH:  b = buy_sell ? rates[con[idx].idxB].high : rates[con[idx].idxB].low; break;
        case LOW:   b = buy_sell ? rates[con[idx].idxB].low : rates[con[idx].idxB].high; break;
        case CLOSE: b = rates[con[idx].idxB].close; break;   
        case RANGE: b = (rates[con[idx].idxB].high - rates[con[idx].idxB].low) / _Point; break;   
        case BODY:  b = MathAbs(rates[con[idx].idxB].open - rates[con[idx].idxB].close) / _Point; break;
        case RATIO: b = MathAbs(rates[con[idx].idxB].open - rates[con[idx].idxB].close) / 
                        (rates[con[idx].idxB].high - rates[con[idx].idxB].low); break;
        case VALUE: a = con[idx].value; break;
        default: return false;
    }

    // compare values
    if (buy_sell || (!buy_sell && con[idx].modeA >= 4)) {
        if(con[idx].comp == GREATER && a > b) { return true;}
        if(con[idx].comp == LESS && a < b) { return true;}
    } else {
        if(con[idx].comp == GREATER && a < b) { return true;}
        if(con[idx].comp == LESS && a > b) { return true;}
    }

    return false;
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