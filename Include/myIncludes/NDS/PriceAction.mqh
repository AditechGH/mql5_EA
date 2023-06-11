#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <myIncludes\NDS\Definitions.mqh>

//+------------------------------------------------------------------+
//|  Class CPriceAction                                              |
//+------------------------------------------------------------------+
class CPriceAction
{
    protected:
        int         trade_count;                // number of trades
        bool        trade_today;                // check if day trading limit is reached
        BAR_INDEX   bar_index;                  // bar index
        double      highest_price;              // hightest price of the last N bar
        double      lowest_price;               // lowest price of the last N ba

    private:
        bool        SetEntryBais();
        double      DefineLevel(double level, BAR_INFO &bar, color clr);
        void        AddRetracements(BAR_INFO &bar);   // add retracement

public:

        TIMEFRAME   timeframe;                 // Default timeframe
        RANGE       range;                      // wick ranges for high time frame
        BAR_INFO    previous_bar;               // previous bar for high time frame
        BAR_INFO    current_bar;                // current bar for high time frame
        RETRACEMENT retracement;                // retracement levels
        ENTRY_BIAS  entry_bias;                 // the direction of the entry. SHORT_ENTRY=sell, LONG_ENTRY=buy, NO_ENTRY=no entry
        bool        pullback_wick_flag;         // pull back wick formed in current high timeframe
        bool        short_position_flag;        // short position
        bool        long_position_flag;         // long position
        double      entry_price;                // entry price
        double      stop_price;                 // stop price
        void        CPriceAction();
        void        ~CPriceAction();
        bool        IsNewBar(ENUM_TIMEFRAMES timeframe);
        bool        BarData(ENUM_TIMEFRAMES timeframe, int barIdx);
        bool        CheckCurrentBar(ENUM_TIMEFRAMES timeframe);
        void        Init(bool Market_data);
        void        DrawLine(string line_name, ENUM_OBJECT type, color line_color, datetime start, double price1 = 0, datetime end = NULL, double price2 = 0, bool delete_line = false);
        void        WriteText(string name, datetime time, double price, color text_color, string text, bool delete_text = false);

};

  // constructor
void CPriceAction::CPriceAction(void) {};

// deconstructor
void CPriceAction::~CPriceAction(void) {};

// Draw line function
void CPriceAction::DrawLine(string name, ENUM_OBJECT type, color line_color, datetime start, double price1 = 0, datetime end = NULL, double price2 = 0, bool delete_line = false) 
{
    if (delete_line) {
        ObjectDelete(NULL, "bar_" + name);
    }
    switch (type)
    {
        case OBJ_TREND:
            ObjectCreate(NULL, "bar_" + name, OBJ_TREND, 0, start, price1, end, price2);
            break;
        case OBJ_VLINE:
            ObjectCreate(NULL, "bar_" + name, OBJ_VLINE, 0, start, 0);
            break;
        default:
            break;
    }
    ObjectSetString(NULL, "bar_" + name, OBJPROP_TOOLTIP, "Entry \n" + DoubleToString(price1, _Digits));
    ObjectSetInteger(NULL, "bar_" + name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 5);
    ObjectSetInteger(NULL, "bar_" + name, OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "bar_" + name, OBJPROP_STYLE, STYLE_SOLID);
}

// Write text function
void CPriceAction::WriteText(string name, datetime time, double price, color text_color, string text, bool delete_text = false) 
{
    if (delete_text) {
        ObjectDelete(NULL, "text_" + name);
    }
    ObjectCreate(NULL, "text_" + name, OBJ_TEXT, 0, time, price);
    ObjectSetInteger(NULL, "text_" + name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    ObjectSetInteger(NULL, "text_" + name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(NULL, "text_" + name, OBJPROP_COLOR, text_color);
    ObjectSetString(NULL, "text_" + name, OBJPROP_TEXT, text);
}

// set bais based on the previous candle
bool CPriceAction::SetEntryBais()
{
    // set bias to no entry
    entry_bias = NO_ENTRY;

    // check to make sure the bar has momentum
    // TODO: or a huge wick rejection.
    if(previous_bar.BODY_RANGE > range.PREV_MIN_BODY_RANGE) 
    {
        // set bias for buy if the pull back wick is not too long
        if (
            previous_bar.DIRECTION == BULLISH // bullish direction
            && (previous_bar.HIGH_WICK_RANGE < range.PREV_MAX_WICK_RANGE || (previous_bar.HIGH_WICK_RANGE > range.PREV_MAX_WICK_RANGE && previous_bar.BODY_RANGE > 1.5*previous_bar.HIGH_WICK_RANGE)) // wick is not too long
            && previous_bar.BODY_RANGE > previous_bar.HIGH_WICK_RANGE) // body range is bigger than wick range
        {
            entry_bias = LONG_ENTRY;
            highest_price = previous_bar.HIGH;
        }
        // set bias for sell if the pull back wick is not too long
        if (
            previous_bar.DIRECTION == BEARISH // bearish direction
            && (previous_bar.LOW_WICK_RANGE < range.PREV_MAX_WICK_RANGE || (previous_bar.LOW_WICK_RANGE > range.PREV_MAX_WICK_RANGE && previous_bar.BODY_RANGE > 1.5*previous_bar.LOW_WICK_RANGE)) // wick is not too long
            && previous_bar.BODY_RANGE > previous_bar.LOW_WICK_RANGE) // body range is bigger than wick
        {
            entry_bias = SHORT_ENTRY;
            lowest_price = previous_bar.LOW;
        }
    }
    // draw potential entry line
    if(entry_bias != NO_ENTRY) 
    {   
        //
        stop_price = previous_bar.DIRECTION == BULLISH ? DBL_MAX : 0.0;
        // set a possible entry price
        entry_price = previous_bar.DIRECTION == BULLISH ? highest_price : lowest_price;
        // draw possible entry line
        DrawLine("entry" + DoubleToString(entry_price), OBJ_TREND, clrBlue,  previous_bar.TIME, entry_price, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(timeframe.HIGH_TIMEFRAME), entry_price, false);
        WriteText("name" + DoubleToString(entry_price), previous_bar.TIME, entry_price, clrBlue, previous_bar.DIRECTION == BULLISH ? "LONG" : "SHORT", false);
        AddRetracements(previous_bar);
    }

    return true;
}

// add retracement levels
void CPriceAction::AddRetracements(BAR_INFO &bar) 
{
    retracement.PRICE_ONE = DefineLevel(retracement.LEVEL_ONE, bar, clrRed);
    retracement.PRICE_TWO = DefineLevel(retracement.LEVEL_TWO, bar, clrGold);
    retracement.PRICE_THREE = DefineLevel(retracement.LEVEL_THREE, bar, clrGreen);
    retracement.PRICE_FOUR = DefineLevel(retracement.LEVEL_FOUR, bar, clrLightGreen);
    retracement.PRICE_FIVE = DefineLevel(retracement.LEVEL_FIVE, bar, clrCyan);
}

// define retracement level    
double CPriceAction::DefineLevel(double level,  BAR_INFO &bar, color clr) 
{
    double price = 0.0;
    if (bar.DIRECTION == BULLISH) 
    {
        price = bar.HIGH - (bar.HIGH - bar.LOW) * level;
    } else 
    {
       price = bar.LOW + (bar.HIGH - bar.LOW) * level;
    }
    DrawLine("entry" + DoubleToString(price), OBJ_TREND, clr, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) - 1, price, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(timeframe.HIGH_TIMEFRAME), price);
    WriteText("name" + DoubleToString(price), iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) - 1, price, clr, DoubleToString(level));

    return price;
}

/** 
 * The functon checks for a new bar open tick
 * 
 * @param period [ENUM_TIMEFRAMES]  timeframe eg PERIOD_CURRENT
 * @return (bool)
*/
bool CPriceAction::IsNewBar(ENUM_TIMEFRAMES period = PERIOD_CURRENT) 
{
   static datetime previousTime = WRONG_VALUE;
   datetime currentTime = iTime(_Symbol, period, 0);
   if(previousTime != currentTime) {
      previousTime = currentTime;
      return true;
   }
   return false;
}

/** 
 * The function retrives and assign bar data to the bar with index
 * 
 * @param period [ENUM_TIMEFRAMES]  timeframe eg PERIOD_H4
 * @param number_of_bars [int]  number of candle bars data to return
 * @param barIdx [int]  bar index
 * @return (bool)
*/
bool CPriceAction::BarData(ENUM_TIMEFRAMES period, int barIdx)
{
    // get bar data
    if (period == timeframe.HIGH_TIMEFRAME) 
    {
        BAR_INFO bar;
        bar.TIME = iTime(_Symbol, period, barIdx);
        bar.OPEN = iOpen(_Symbol, period, barIdx);
        bar.CLOSE = iClose(_Symbol, period, barIdx);
        bar.HIGH = iHigh(_Symbol, period, barIdx);
        bar.LOW = iLow(_Symbol, period, barIdx);
        bar.VOLUME = iTickVolume(_Symbol, period, barIdx);
        bar.BODY_RANGE = fabs(bar.OPEN - bar.CLOSE) / _Point;
        bar.LOW_WICK_RANGE = (bar.OPEN >= bar.CLOSE) ? fabs(bar.LOW - bar.CLOSE) / _Point : fabs(bar.LOW - bar.OPEN) / _Point;
        bar.HIGH_WICK_RANGE = (bar.OPEN >= bar.CLOSE) ? fabs(bar.HIGH - bar.OPEN) / _Point : fabs(bar.HIGH - bar.CLOSE) / _Point;
        bar.DIRECTION = (bar.OPEN >= bar.CLOSE) ? BEARISH : BULLISH;

        // set bar 
        if (barIdx == bar_index.CURRENT_BAR_IDX) 
            current_bar = bar;
        else if (barIdx == bar_index.PREVIOUS_BAR_IDX)
            previous_bar = bar;
        else
            return false;
    } 
    else 
    {
        return false;
    }
    return true;
}

/** 
 * The function checks the current bar on the high timeframe for possible entries
 * 
 * @param period [ENUM_TIMEFRAMES]  timeframe eg H4_PERIOD
 * @return (bool)
*/
bool CPriceAction::CheckCurrentBar(ENUM_TIMEFRAMES period)
{
    // get current bar information
    bool get_bar = BarData(timeframe.HIGH_TIMEFRAME, bar_index.CURRENT_BAR_IDX);
    if(!get_bar) return false;

    // exit if an entry bias is not set
    if(entry_bias == NO_ENTRY) return false;

    // exit if a trade has already been set
    if (short_position_flag || long_position_flag) return false;

    // no entry if bar is not in the same direction as previous bar
    if (current_bar.DIRECTION != previous_bar.DIRECTION ) return false;

    // check for buy if a pull back wick has been created and is not too short
    if (
        current_bar.DIRECTION == BULLISH && current_bar.LOW_WICK_RANGE > range.CURR_MIN_WICK_RANGE)
    {   
        pullback_wick_flag = true;
        // set a new possible buy entry
        entry_price = highest_price - current_bar.LOW_WICK_RANGE * _Point;
        DrawLine("New Entry", OBJ_TREND, clrBlue,  iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) - 1, entry_price, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(timeframe.HIGH_TIMEFRAME), entry_price, true);
        WriteText("new entry", previous_bar.TIME, entry_price, clrBlue, previous_bar.DIRECTION == BULLISH ? "LONG" : "SHORT", true);
    }

    // check for sell if a pull back wick has been created and is not too short
    if (
        current_bar.DIRECTION == BEARISH && current_bar.HIGH_WICK_RANGE > range.CURR_MIN_WICK_RANGE)
    {
        pullback_wick_flag = true;
        // set a new possible sell entry
        entry_price = lowest_price + current_bar.HIGH_WICK_RANGE * _Point;
        DrawLine("New Entry", OBJ_TREND, clrBlue, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) - 1, entry_price,  iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(timeframe.HIGH_TIMEFRAME), entry_price, true);
        WriteText("New Entry", previous_bar.TIME, entry_price, clrBlue, previous_bar.DIRECTION == BULLISH ? "LONG" : "SHORT", true);
    
    }
    
    return true;
}

/** 
 * Price action init function
 * 
 * @return (void)
*/
void  CPriceAction::Init(bool Market_data)
{
    global.NO_OF_CANDLES = 0;
    global.FIRST_CANDLE = true;  
    global.LIVE_MARKET = Market_data;
    pullback_wick_flag = false;
    BarData(timeframe.HIGH_TIMEFRAME, bar_index.PREVIOUS_BAR_IDX);
    DrawLine("newLine"+ TimeToString(TimeCurrent()), OBJ_VLINE, clrDarkGoldenrod, TimeCurrent());
    SetEntryBais();
}