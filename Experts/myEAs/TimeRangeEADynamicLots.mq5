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
input long   inputMagicNumber   = 22222;                    // magic number

enum LOT_MODE_ENUM{
    LOT_MODE_FIXED,                                         // fixed lot
    LOT_MODE_MONEY,                                         // lots based on money
    LOT_MODE_PCT_ACCOUNT                                    // lots based on % of account
};
input LOT_MODE_ENUM inputLotMode = LOT_MODE_FIXED;          // lot mode  

input double inputLots          = 0.1;                        // lots / money / percent
input int    inputStopLoss      = 150;                      // stop loss in % of the range (0=off)
input int    inputTakeProfit    = 150;                      // take profit in % of the range (0=off)

input group "==== Range Inputs ===="
input int    inputRangeStart    = 600;                      // range start time in minutes
input int    inputRangeDuration = 120;                      // range duration in minutes
input int    inputRangeClose    = 1200;                     // range close time in minutes (-1=off)
enum BREAKOUT_MODE_ENUM {
    ONE_SIGNAL,                                             // one breakout per range  
    TWO_SIGNALS                                             // high and low breakout   
};
input BREAKOUT_MODE_ENUM inputBreakoutMode = ONE_SIGNAL;    // breakout mode

input group "==== Day of the week filter ===="
input bool   inputMonday        = true;                     // range on monday
input bool   inputTuesday       = true;                     // range on tuesday
input bool   inputWednesDay     = true;                     // range on wednesday
input bool   inputThursday      = true;                     // range on thursday
input bool   inputFriday        = true;                     // range on friday

input group "==== Equity ===="
input int    inputMaxEquity     = 6;                       // stop out if profit reaches the percentage (100=off) 
input int    inputMinEquity     = 6;                       // stop out if loss reaches the percentage (100=off) 
input int    inputStartBalane   = 25000;                   // account balance

//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+

// static variables
static int      SECONDS_OF_ONE_DAY  = 86400;
static int      SUNDAY              = 0;
static int      MONDAY              = 1;
static int      TUESDAY             = 2;
static int      WEDNESDAY           = 3;
static int      THURSDAY            = 4;
static int      FRIDAY              = 5;
static int      SATURDAY            = 6;
static string   EA                  = "Time Range EA";

struct RANGE_STRUCT {
    datetime start_time;        // start of the range
    datetime end_time;          // end of the range
    datetime close_time;        // close time
    double high;                // high of the range
    double low;                 // low of the range  
    bool flag_entry;            // flag if we are in a range  
    bool flag_high_breakout;    // flag if a high breakout occurred
    bool flag_low_breakout;     // flag if a low breakout occurred

    RANGE_STRUCT(): start_time(0), end_time(0), close_time(0), high(0), low(DBL_MAX), flag_entry(false), flag_high_breakout(false), flag_low_breakout(false) {}; 
};

RANGE_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {  

    // check user inputs
    if(!CheckInputs()) return INIT_PARAMETERS_INCORRECT;
  
    // set magic number to trade object
    trade.SetExpertMagicNumber(inputMagicNumber);

    // calculated new range if inputs changed
    if(_UninitReason==REASON_PARAMETERS && CountOpenPositions() == 0) CalculateRange();

    // draw objects
    DrawObjects();

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

    // delete Object
    ObjectsDeleteAll(NULL, "range");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // get current tick
    prevTick = lastTick;
    SymbolInfoTick(_Symbol, lastTick);

    // range calculation
    if (lastTick.time >= range.start_time && lastTick.time < range.end_time) {
        // set flag
        range.flag_entry = true;
        //new high
        if (lastTick.ask > range.high) {
            range.high = lastTick.ask;
            DrawObjects();
        }
        //new low
        if (lastTick.bid < range.low) {
            range.low = lastTick.bid;
            DrawObjects();
        } 
    }

    // close positions
    if (inputRangeClose >= 0 && lastTick.time >= range.close_time) {
        if (!ClosePositions()) return;
    }      

    // calculate the range if ...
    if ( ((inputRangeClose >= 0 && lastTick.time >= range.close_time)                     // close time reached
        || (range.flag_low_breakout || range.flag_high_breakout)                          // both breakout flags are true
        || (range.end_time == 0)                                                          // range not calculated yet
        || (range.end_time != 0 && lastTick.time > range.end_time && !range.flag_entry))  // there was a range calculated but no tick inside
        // CountOpenPosition() == 0
        && CountOpenPositions() == 0
        ) {
            CalculateRange();
        }

    // check for breackouts
    CheckBreakouts();
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
    if(inputLotMode == LOT_MODE_FIXED && (inputLots <= 0 || inputLots > 10)) {
        Alert("Lots <= 0 or > 10");
        return false;
    }
    if(inputLotMode == LOT_MODE_MONEY && (inputLots <= 0 || inputLots > 1000)) {
        Alert("Lots <= 0 or > 1000");
        return false;
    }
    if(inputLotMode == LOT_MODE_PCT_ACCOUNT && (inputLots <= 0 || inputLots > 5)) {
        Alert("Lots <= 0 or > 5");
        return false;
    }
    if((inputLotMode == LOT_MODE_PCT_ACCOUNT || inputLotMode == LOT_MODE_MONEY) && inputStopLoss == 0) {
        Alert("Selected lot mode needs a stop loss");
        return false;
    }
    if(inputStopLoss < 0 || inputStopLoss > 1000) {
      Alert("Stop loss  < 0 or > 1000");
      return false;
    }
    if(inputTakeProfit < 0 || inputTakeProfit > 1000) {
      Alert("Take profit < 0 or > 1000");
      return false;
    }
    if(inputRangeClose < 0 && inputStopLoss == 0) {
      Alert("Close time and stop loss is off");
      return false;
    }
    if(inputRangeStart < 0 || inputRangeStart >= 1440) {
        Alert("Range start < 0 or >= 1440");
        return false;
    }
    if(inputRangeDuration <= 0 || inputRangeDuration >= 1440) {
        Alert("Range duration <= 0 or >= 1440");
        return false;
    }
    if(inputRangeClose >= 1440 || (inputRangeStart+inputRangeDuration)%1440 == inputRangeClose) {
        Alert("Close time < 0 or >= 1440 or end time == close time");
        return false;
    }
    if(inputMonday + inputTuesday + inputWednesDay + inputThursday + inputFriday == 0) {
        Alert("Range is prohibited on all days of the week");
        return false;
    }
    if(inputMinEquity < 0 || inputMinEquity > 100) {
        Alert("Min stop out 0 < or > 100");
        return false;
    }
    if(inputMaxEquity < 0 || inputMaxEquity > 100) {
        Alert("Max stop out 0 < or > 100");
        return false;
    }
    if(inputStartBalane <= 0) {
        Alert("Start Balance out <= 100");
        return false;
    }
    return true;
}

// calculate a new range
void CalculateRange() {

    // Exit EA if Equity Stop out reached
    if(EquityStopOut()) ExpertRemove();

    // reset range variables
    range.start_time = 0;
    range.end_time = 0;
    range.close_time = 0;
    range.high = 0.0;
    range.low = DBL_MAX;
    range.flag_entry = false;
    range.flag_low_breakout = false;
    range.flag_high_breakout = false;

    // calculate range start time
    int time_cycle = SECONDS_OF_ONE_DAY;
    range.start_time = (lastTick.time - (lastTick.time % time_cycle)) + inputRangeStart * 60;
    for (int i = 0; i < 8; i++) {
        MqlDateTime tmp;
        TimeToStruct(range.start_time, tmp);
        int dow = tmp.day_of_week;
        if (
            lastTick.time >= range.start_time  
            || dow == SATURDAY 
            || dow == SUNDAY 
            || (dow == MONDAY && !inputMonday)
            || (dow == TUESDAY && !inputTuesday)
            || (dow == WEDNESDAY && !inputWednesDay)
            || (dow == THURSDAY && !inputThursday)
            || (dow == FRIDAY && !inputFriday)) {
            range.start_time += time_cycle;
        } 
    }

    // calculate range end time
    range.end_time = range.start_time + inputRangeDuration * 60;
    for (int i = 0; i < 2; i++) {
        MqlDateTime tmp;
        TimeToStruct(range.end_time, tmp);
        int dow = tmp.day_of_week;
        if (dow == 6 || dow == 0) {
            range.end_time += time_cycle;
        }
    }

    // calculate range close
    if (inputRangeClose >= 0) {
        range.close_time = (range.end_time - (range.end_time % time_cycle)) + inputRangeClose * 60;
        for (int i = 0; i < 3; i++) {
            MqlDateTime tmp;
            TimeToStruct(range.close_time, tmp);
            int dow = tmp.day_of_week;
            if (range.close_time <= range.end_time  || dow == SATURDAY || dow == SUNDAY) {
                range.close_time += time_cycle;
            } 
        }
    }

    // draw objects
    DrawObjects();
}

// check for breakouts
void CheckBreakouts() {

    // check if we are after the range end
    if (lastTick.time >= range.end_time && range.end_time > 0 && range.flag_entry) {

        // check for high breakout
        if (!range.flag_high_breakout && lastTick.ask >= range.high) {
            range.flag_high_breakout = true;
            if (inputBreakoutMode == ONE_SIGNAL) range.flag_low_breakout = true;

            // open buy position
            double sl = CalcuteStopLoss(1);
            double tp = CalculateTakeProfit(1);

            // calculate lots
            double lots;
            if(!CalculateLots(lastTick.bid - sl, lots)) return;

            trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lots, lastTick.ask, sl, tp, EA);
        }

        // check for low breakout
        if (!range.flag_low_breakout && lastTick.bid <= range.low) {
            range.flag_low_breakout = true;
            if (inputBreakoutMode == ONE_SIGNAL) range.flag_high_breakout = true;

            // open sell position
            double sl = CalcuteStopLoss(2);
            double tp = CalculateTakeProfit(2);
            
            // calculate lots
            double lots;
            if(!CalculateLots(sl - lastTick.bid, lots)) return;

            trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lots, lastTick.bid, sl, tp, EA);
        }
    }
}

// close positions
bool ClosePositions() {

    int total = PositionsTotal();
    for(int i = total-1; i>=0; i--) {
        if(total != PositionsTotal()) {
            total = PositionsTotal();
            continue;
        }
        ulong ticket = PositionGetTicket(i); // select position
        if(ticket <= 0) {
            Print("Failed to get position ticket");
            return false;
        }
        if(!PositionSelectByTicket(ticket)) {
            Print("Failed to select position by ticket");
            return false;
        }
        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic)) {
            Print("Failed to get position magic number");
            return false;
        }
        if(magic == inputMagicNumber) {
            trade.PositionClose(ticket);
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print("Failed to close position. ticket: ", (string)ticket, " result: ", (string)trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
                return false;
            }
        }
    }
    return true;
}

// draw lines on chart
void DrawObjects() {

    // start time
    ObjectDelete(NULL, "range start");
    if (range.start_time > 0) {
        ObjectCreate(NULL, "range start", OBJ_VLINE, 0, range.start_time, 0);
        ObjectSetString(NULL, "range start", OBJPROP_TOOLTIP, "start of the range \n" + TimeToString(range.start_time, TIME_DATE|TIME_MINUTES));
        ObjectSetInteger(NULL, "range start", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range start", OBJPROP_BACK, true);
    }

    // end time
    ObjectDelete(NULL, "range end");
    if (range.end_time > 0) {
        ObjectCreate(NULL, "range end", OBJ_VLINE, 0, range.end_time, 0);
        ObjectSetString(NULL, "range end", OBJPROP_TOOLTIP, "end of the range \n" + TimeToString(range.end_time, TIME_DATE|TIME_MINUTES));
        ObjectSetInteger(NULL, "range end", OBJPROP_COLOR, clrDarkBlue);
        ObjectSetInteger(NULL, "range end", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range end", OBJPROP_BACK, true);
    }

    // close time
    ObjectDelete(NULL, "range close");
    if (range.close_time > 0) {
        ObjectCreate(NULL, "range close", OBJ_VLINE, 0, range.close_time, 0);
        ObjectSetString(NULL, "range close", OBJPROP_TOOLTIP, "close of the range \n" + TimeToString(range.close_time, TIME_DATE|TIME_MINUTES));
        ObjectSetInteger(NULL, "range close", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(NULL, "range close", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range close", OBJPROP_BACK, true);
    }

    // high
    ObjectsDeleteAll(NULL, "range high");
    if (range.high > 0) {
        ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.start_time, range.high, range.end_time, range.high);
        ObjectSetString(NULL, "range high", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, _Digits));
        ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

        ObjectDelete(NULL, "range high ");
        ObjectCreate(NULL, "range high ", OBJ_TREND, 0, range.end_time, range.high, inputRangeClose >= 0 ? range.close_time: INT_MAX, range.high);
        ObjectSetString(NULL, "range high ", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, _Digits));
        ObjectSetInteger(NULL, "range high ", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range high ", OBJPROP_BACK, true);
        ObjectSetInteger(NULL, "range high ", OBJPROP_STYLE, STYLE_DOT);
    }

    // low
    ObjectsDeleteAll(NULL, "range low");
    if (range.low < DBL_MAX) {
        ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.start_time, range.low, range.end_time, range.low);
        ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP, "low of the range \n" + DoubleToString(range.low, _Digits));
        ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);

        ObjectCreate(NULL, "range low ", OBJ_TREND, 0, range.end_time, range.low, inputRangeClose >= 0 ? range.close_time: INT_MAX, range.low);
        ObjectSetString(NULL, "range low ", OBJPROP_TOOLTIP, "low of the range \n" + DoubleToString(range.low, _Digits));
        ObjectSetInteger(NULL, "range low ", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range low ", OBJPROP_BACK, true);
        ObjectSetInteger(NULL, "range low ", OBJPROP_STYLE, STYLE_DOT);
    }

    // refresh chart
    ChartRedraw();
}

// calculate lots
bool CalculateLots(double slDistance, double &lots) {

    lots = 0.0;
    if(inputLotMode == LOT_MODE_FIXED) {
        lots = inputLots;
    }
    else {
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        double riskMoney = inputLotMode == LOT_MODE_MONEY ? inputLots : AccountInfoDouble(ACCOUNT_EQUITY) * inputLots * 0.01;
        double moneyVolumeStep = (slDistance / tickSize) * tickValue * volumeStep;

        lots = MathFloor(riskMoney/moneyVolumeStep) * volumeStep;
    }

    // check calculated lots
    if(!CheckLots(lots)) return false;

    return true;
}

// check lots for min, max and step
bool CheckLots(double &lots) {

    double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(lots < min) {
        Print("Lot size will be set to the minimum allowable volume");
        lots = min;
        return true;
    }

    if(lots > max) {
        Print("Lot size greater than the maximum available volume: ", lots, " max: ", max);
        return false;
    }

    lots = (int) MathFloor(lots/step) * step;

    return true;
}

// calculate stop loss points
double CalcuteStopLoss(int type) {
    double sl = type == 1 ?
        lastTick.bid - ((range.high - range.low) * inputStopLoss * 0.01) :
        lastTick.ask + ((range.high - range.low) * inputStopLoss * 0.01);
    return inputStopLoss == 0 ? 0 :  NormalizeDouble(sl, _Digits);
} 

// calculate take profit points
double CalculateTakeProfit(int type) { 
    double tp = type == 1 ?
        lastTick.bid + ((range.high - range.low) * inputTakeProfit * 0.01) :
        lastTick.ask - ((range.high - range.low) * inputTakeProfit * 0.01);
    return inputTakeProfit == 0 ? 0 :  NormalizeDouble(tp, _Digits);
}

// count open positions
int CountOpenPositions() {
    int counter = 0;
    int total = PositionsTotal();
    for(int i = total - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) { 
            Print("Failed to get position ticket"); 
            return -1; 
        }
        if(!PositionSelectByTicket(ticket)) { 
            Print("Failed to select position"); 
            return -1; 
        }

        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic)) { 
            Print("Failed to get position magic number"); 
            return false; 
        }
        if(magic == inputMagicNumber) {
            counter++;
        }
   }
   return counter;
}

// equity stop out
bool EquityStopOut () {
    double diff = AccountInfoDouble(ACCOUNT_BALANCE) - inputStartBalane;
    double percentile = (MathAbs(diff) * 100) / inputStartBalane;
    return ( (diff > 0 && percentile >= inputMaxEquity) || (diff < 0 && percentile >= inputMinEquity));
}
