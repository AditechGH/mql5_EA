#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <myIncludes\NDS\Definitions.mqh>
#include <myIncludes\NDS\CandleTypes.mqh>

//+------------------------------------------------------------------+
//|  Class CPriceAction                                              |
//+------------------------------------------------------------------+
class CPriceAction : CCandleTypes
{
    private:
        bool                SetEntryBais();
        void                AddRetracements(CANDLE_STRUCTURE &bar);
        double              DefineLevel(double level, CANDLE_STRUCTURE &bar, color clr);

public:

        TIMEFRAME           timeframe;                  // Default timeframe
        RETRACEMENT         retracement;                // retracement levels
        ENTRY_BIAS          entry_bias;                 // the direction of the entry. SHORT_ENTRY=sell, LONG_ENTRY=buy, NO_ENTRY=no entry
        CANDLE_STRUCTURE    prev_candle;                // previous candlestick
        double              entry_price;                // entry price
        double              stop_price;                 // stop price
        void                CPriceAction();
        void                ~CPriceAction();
        void                Init(bool Market_data);
        void                DrawLine(string line_name, ENUM_OBJECT type, color line_color, datetime start, double price1 = 0, datetime end = NULL, double price2 = 0, bool delete_line = false);
        void                WriteText(string name, datetime time, double price, color text_color, string text, bool delete_text = false);
};

// constructor
void CPriceAction::CPriceAction(void) {};

// deconstructor
void CPriceAction::~CPriceAction(void) {};

// set bais based on the previous candle
bool CPriceAction::SetEntryBais()
{
    // set bias to no entry
    entry_bias = NO_ENTRY;

    if(!RecognizeCandle(timeframe.HIGH_TIMEFRAME, 1, 6, prev_candle)) return false;

    // set bias for buy
    if((prev_candle.bull && (prev_candle.type == CAND_LONG || prev_candle.type == CAND_MARIBOZU_LONG)) || prev_candle.type == CAND_HAMMER_LONG)
    {
        entry_bias = LONG_ENTRY;
    }
    // set bias for sell
     if((!prev_candle.bull && (prev_candle.type == CAND_LONG || prev_candle.type == CAND_MARIBOZU_LONG)) || prev_candle.type == CAND_INVERT_HAMMER_LONG)
    {
        entry_bias = SHORT_ENTRY;
    }

    // if entry bias is set
    if(entry_bias != NO_ENTRY) 
    {   
        // set stop price
        stop_price = prev_candle.bull ? DBL_MAX : 0.0;
        // set entry price
        entry_price = prev_candle.bull ? prev_candle.close + 10 * _Point : prev_candle.close - 10 * _Point;
        // draw entry line
        DrawLine("entry" + DoubleToString(entry_price), OBJ_TREND, clrBlue,  prev_candle.time, entry_price, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(timeframe.HIGH_TIMEFRAME), entry_price, false);
        WriteText("name" + DoubleToString(entry_price), prev_candle.time, entry_price, clrBlue, prev_candle.bull ? "LONG" : "SHORT", false);
        AddRetracements(prev_candle);
    }

    return true;
}

// add retracement levels
void CPriceAction::AddRetracements(CANDLE_STRUCTURE &cand) 
{
    retracement.PRICE_ONE = DefineLevel(retracement.LEVEL_ONE, cand, clrRed);
    retracement.PRICE_TWO = DefineLevel(retracement.LEVEL_TWO, cand, clrGold);
    retracement.PRICE_THREE = DefineLevel(retracement.LEVEL_THREE, cand, clrGreen);
    retracement.PRICE_FOUR = DefineLevel(retracement.LEVEL_FOUR, cand, clrLightGreen);
    retracement.PRICE_FIVE = DefineLevel(retracement.LEVEL_FIVE, cand, clrCyan);
}

// define retracement level    
double CPriceAction::DefineLevel(double level, CANDLE_STRUCTURE &cand, color clr) 
{
    double price = 0.0;
    if (cand.bull) 
    {
        price = cand.high - (cand.high - cand.low) * level;
    } else 
    {
       price = cand.low + (cand.high - cand.low) * level;
    }
    DrawLine("entry" + DoubleToString(price), OBJ_TREND, clr, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) - 1, price, iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(timeframe.HIGH_TIMEFRAME), price);
    WriteText("name" + DoubleToString(price), iTime(_Symbol, timeframe.HIGH_TIMEFRAME, 0) - 1, price, clr, DoubleToString(level));

    return price;
}


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
void 
CPriceAction::WriteText(string name, datetime time, double price, color text_color, string text, bool delete_text = false) 
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
    DrawLine("newLine"+ TimeToString(TimeCurrent()), OBJ_VLINE, clrDarkGoldenrod, TimeCurrent());
    SetEntryBais();
}