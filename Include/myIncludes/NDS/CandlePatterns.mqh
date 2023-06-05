#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <myIncludes\NDS\Definitions.mqh>


color ColorBull   =DodgerBlue; // Color of bullish models
color ColorBear   =Tomato;     // Color of bearish models

//+------------------------------------------------------------------+
//|  Class CCandlePatterns                                            |
//+------------------------------------------------------------------+
class CCandlePatterns 
{
    private:
        void        DrawSignal(string objname, CANDLE_STRUCTURE &cand, color Col);
        void        DrawSignal(string objname,CANDLE_STRUCTURE &cand1,CANDLE_STRUCTURE &cand2,color Col);
        void        DrawSignal(string objname,CANDLE_STRUCTURE &cand1,CANDLE_STRUCTURE &cand2,CANDLE_STRUCTURE &cand3,color Col);

    public:
        bool        _forex;
        void        CCandlePatterns();
        void        ~CCandlePatterns();
        bool        RecognizeCandle(ENUM_TIMEFRAMES period, int start_position, int aver_period, CANDLE_STRUCTURE &res);
        bool        ReversalPatterns(TREND &trend);
        bool        BullishReversals(CANDLE_STRUCTURE &cand1);        
        bool        BearishReversals(CANDLE_STRUCTURE &cand1);
        bool        BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2);
        bool        BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2);
        bool        BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3);
        bool        BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3);
        bool        BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4);
        bool        BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4);
        bool        BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4, CANDLE_STRUCTURE &cand5);
        bool        BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4, CANDLE_STRUCTURE &cand5);
        bool        ContinuesPattern(int rates_total);
};

  // constructor
void CCandlePatterns::CCandlePatterns(void) {
    if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE) == (int) SYMBOL_CALC_MODE_FOREX) _forex = true;
    Print(PREFIX, "inside the constructor, _forex:", _forex);
};

// deconstructor
void CCandlePatterns::~CCandlePatterns(void) {};


// Function of recognition of candlestick type                      
bool CCandlePatterns::RecognizeCandle(ENUM_TIMEFRAMES period, int start_position, int aver_period, CANDLE_STRUCTURE &res)
{
    MqlRates rates[];
    // Get data of previous candlesticks
    if(CopyRates(_Symbol, period, start_position, aver_period + 1, rates) < aver_period) return(false);

    res.open = rates[aver_period].open;
    res.high = rates[aver_period].high;
    res.low = rates[aver_period].low;
    res.close = rates[aver_period].close;
    res.time = rates[aver_period].time;

    // Define the trend direction
    double aver = 0;
    for (int i = 0; i < aver_period; i++)
        aver += rates[i].close;
    aver = aver / aver_period;
   
    if (aver < res.close) res.trend = UPPER;
    if (aver > res.close) res.trend = DOWN;
    if (aver == res.close) res.trend = LATERAL;

    // Define of it bullish or bearish
    res.bull = res.open < res.close;

    // Get the absolute value of the candlestick body size
    res.bodysize = MathAbs(res.open - res.close);

    // Get the size of shadows
    double shade_low = res.close - res.low;
    double shade_high = res.high - res.open;

    if (res.bull)
    {
      shade_low = res.open - res.low;
      shade_high = res.high - res.close;
    }
    double HL = res.high - res.low;

    // Calculate the average body size of previous candlesticks
    double sum = 0;
    for (int i = 1; i <= aver_period; i++)
        sum = sum + MathAbs(rates[i].open - rates[i].close);
    sum=sum/aver_period;

    // Determine type of candlestick   
    res.type = CAND_NONE;
    // long 
    if (res.bodysize > sum * 1.3) res.type = CAND_LONG;
    // shorates 
    if (res.bodysize < sum * 0.5) res.type = CAND_SHORT;
    // doji
    if (res.bodysize < HL * 0.03) res.type = CAND_DOJI;
    // maribozu
    if ((shade_low < res.bodysize * 0.01 || shade_high < res.bodysize * 0.01) && res.bodysize > 0)
        res.type = (res.type == CAND_LONG) ? res.type = CAND_MARIBOZU_LONG : res.type = CAND_MARIBOZU;
    // hammer
    if (shade_low > res.bodysize * 2 && shade_high < res.bodysize * 0.1) res.type = CAND_HAMMER;
    // inverates hammer
    if (shade_low < res.bodysize * 0.1 && shade_high > res.bodysize * 2) res.type = CAND_INVERT_HAMMER;
    // spinning top
    if (res.type == CAND_SHORT && shade_low > res.bodysize && shade_high > res.bodysize) res.type = CAND_SPIN_TOP;
    ArrayFree(rates);
    return true;
}

// Function for checking possible reversals
bool CCandlePatterns::ReversalPatterns(TREND &trend) 
{

    if(global.LIVE_MARKET && !SeriesInfoInteger(_Symbol , 0, SERIES_SYNCHRONIZED)) return false;

    CANDLE_STRUCTURE cand1;
    if(!RecognizeCandle(PERIOD_CURRENT, 1, global.NO_OF_CANDLES, cand1)) return false;

    if(trend == BULLISH) 
    {
        BullishReversals(cand1);
    }
    else
    {
        BearishReversals(cand1);
    }
   
    return true;
}

// Function for checking possible reveasal to the upside -- 1 candlestick
bool CCandlePatterns::BullishReversals(CANDLE_STRUCTURE &cand1)
{
    // Inverted Hammer 
    if(cand1.trend == DOWN && cand1.type == CAND_INVERT_HAMMER)
    {
        DrawSignal("Invert Hammer"+ TimeToString(TimeCurrent()),cand1, ColorBull);
    }
    // Hammer
    if (cand1.trend == DOWN && cand1.type == CAND_HAMMER) 
    {
        DrawSignal("Hammer"+ TimeToString(TimeCurrent()),cand1, ColorBull);
    }

    // Check of patterns with two candlesticks
    CANDLE_STRUCTURE cand2;
    if(!RecognizeCandle(PERIOD_CURRENT, 2, global.NO_OF_CANDLES, cand2)) return false;
    BullishReversals(cand1, cand2);

    return true;
}

// Function for checking possible reveasal to the upside -- 2 candlesticls
bool CCandlePatterns::BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2)
{
    // Belt Hold
    // body of the first candlestick is smaller than body of the second one, close price of the second candlestick is lower than the close price of the first one
    if (cand2.trend==DOWN && cand2.bull && !cand1.bull &&  cand2.type==CAND_MARIBOZU_LONG && cand1.bodysize<cand2.bodysize && cand2.close<cand1.close)
    {
        if(!_forex)
        {
            DrawSignal("Belt Hold" + TimeToString(TimeCurrent()), cand2, ColorBull);
        }
    }

    // Engulfing
    // body of the third candlestick is bigger than that of the second one
    if (cand1.trend==DOWN && !cand1.bull && cand2.trend==DOWN && cand2.bull && cand1.bodysize<cand2.bodysize)
    {
        if(_forex)
        {
            // body of the first candlestick is inside of body of the second one
            if(cand1.close>=cand2.open && cand1.open<cand2.close)
            {
                DrawSignal("Engulfing" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
        else
        {
            // body of the first candlestick inside of body of the second candlestick
            if(cand1.close>cand2.open && cand1.open<cand2.close)
            {
                DrawSignal("Engulfing" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
    }

    // Harami Cross
    // check of "long" first candlestick and Doji candlestick
    if (cand1.trend==DOWN && !cand1.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand2.type==CAND_DOJI)
    {
        if(_forex)
        {   // Doji is inside of body of the first candlestick
            if(cand1.close<=cand2.open && cand1.close<=cand2.close && cand1.open>cand2.close)
            {
                DrawSignal("Harami Cross" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
        else
        {
            // Doji is inside of body of the first candlestick
            if(cand1.close<cand2.open && cand1.close<cand2.close && cand1.open>cand2.close)
            {
               DrawSignal("Harami Cross" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
    }

    // Harami
    // the second candlestick is not Doji and body of the first candlestick is bigger than that of the second one
    if (cand1.trend==DOWN  &&  !cand1.bull  &&  cand2.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand2.type!=CAND_DOJI && cand1.bodysize>cand2.bodysize)
    {
        if(_forex)
        {
            // body of the second candlestick is inside of body of the first candlestick
            if (cand1.close<=cand2.open && cand1.close<=cand2.close && cand1.open>cand2.close)
            {
               DrawSignal("Harami" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
        else
        {
            // body of the second candlestick is inside of body of the first one
            if (cand1.close<cand2.open && cand1.close<cand2.close && cand1.open>cand2.close)
            {
               DrawSignal("Harami" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
    }

    // Doji Star
    // check direction of trend and direction of candlestick
    // check first "long" candlestick and 2 doji
    if (cand1.trend==DOWN && !cand1.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand2.type==CAND_DOJI) 
    {
        if(_forex)
        {
            // Open price of Doji is lower or equal to close price of the first candlestick
            if(cand1.close>=cand2.open)
            {
                DrawSignal("Doji Star" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
        else
        {
            // Body of Doji is cut off the body of the first candlestick
            if(cand1.close>cand2.open && cand1.close>cand2.close) 
            {
                DrawSignal("Doji Star" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
    }
    
    // Piercing Line
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // close price of the second candle is higher than the middle of the first one
    if (cand1.trend==DOWN && !cand1.bull && cand2.trend==DOWN && cand2.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) && cand2.close>(cand1.close+cand1.open)/2)
    {
        if(_forex)
        {
            if (cand1.close>=cand2.open && cand2.close<=cand1.open)
            {
                DrawSignal("Piercing Line" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
        else
        {
            // open price of the second candle is lower than LOW price of the first one 
            if (cand2.open<cand1.low && cand2.close<=cand1.open)
            {
                DrawSignal("Piercing Line" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
            }
        }
    }
    
    // Meeting Lines
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // close prices are equal, size of the first candlestick is smaller than that of the second one; open price of the second one is lower than minimum of the first one
    if(cand1.trend==DOWN && !cand1.bull && cand2.trend==DOWN && cand2.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) && cand1.close==cand2.close && cand1.bodysize<cand2.bodysize && cand1.low>cand2.open)
    {
        if(!_forex)
        {
            DrawSignal("Meeting Lines" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
        }
    }
    
    // Matching Low
    // check direction of trend and direction of candlestick
    // close price are equal, size of the first one is greater than that of the second one
    if(cand1.trend==DOWN && !cand1.bull && cand2.trend==DOWN && !cand2.bull && cand1.close==cand2.close && cand1.bodysize>cand2.bodysize) 
    {
        if(!_forex)
        {
            DrawSignal("Meeting Low" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
        }
    }
   
    // Homing Pigeon
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // body of the second candlestick is inside of body of the first one
    if(cand1.trend==DOWN && !cand1.bull && cand2.trend==DOWN && !cand2.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand1.close<cand2.close  &&  cand1.open>cand2.open) 
    {
        if(!_forex)
        {
            DrawSignal("Homing Pigeon" + TimeToString(TimeCurrent()),cand1, cand2, ColorBull);
        }
    }
    

    // Check of patterns with three candlesticks
    CANDLE_STRUCTURE cand3;
    if(!RecognizeCandle(PERIOD_CURRENT, 3, global.NO_OF_CANDLES, cand3)) return false;
    BullishReversals(cand1, cand2, cand3);

    return true;
}

// Function for checking possible reveasal to the upside -- 3 candlesticls
bool CCandlePatterns::BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3)
{
    // The Abandoned Baby
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // check if the second candlestick is Doji
    // the third one is closed inside of body of the first one
    if(cand1.trend==DOWN && !cand1.bull && cand3.trend==DOWN && cand3.bull &&
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) &&
        cand2.type==CAND_DOJI && cand3.close<cand1.open && cand3.close>cand1.close) 
    {
        if(!_forex)
        {
            // gap between candlesticks
            if(cand1.low>cand2.high && cand3.low>cand2.high)
            {
                DrawSignal("Abandoned Baby" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Morning star
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // check of "short" candlestick
    // the third candlestick is closed inside of body of the first one
    if(cand1.trend==DOWN && !cand1.bull && cand3.trend==DOWN && cand3.bull && 
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) &&
         cand2.type==CAND_SHORT &&  cand3.close>cand1.close && cand3.close<cand1.open) 
    {
        if(_forex) // forex
        {
            // Open price of the second candlestick is lower than the closing of the first one
            if(cand2.open<=cand1.close)
            {
                DrawSignal("Morning star" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
        else // other market
        {
            // distance from the second candlestick to the first one
            if(cand2.open<cand1.close && cand2.close<cand1.close)
            {
                DrawSignal("Morning star" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Morning Doji Star
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // check of "doji"
    // the third candlestick is closed inside of body of the first one
    if(cand1.trend==DOWN && !cand1.bull && cand3.trend==DOWN && cand3.bull && 
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) &&
        cand2.type==CAND_DOJI && cand3.close>cand1.close && cand3.close<cand1.open)
    {
        if(_forex)
        {
            // open price of Doji is lower or equal to the close price of the first candlestick
            if(cand2.open<=cand1.close) 
            {
                DrawSignal("Morning Doji Star" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
        else // other market
        {
            // gap between Doji and the first candlestick
            if(cand2.open<cand1.close)
            {
                DrawSignal("Morning Doji Star" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Three Star in the South
    // check direction of trend and direction of candlestick
    // check of "long" candlestick and "maribozu"
    if(cand1.trend==DOWN && !cand1.bull && !cand2.bull && !cand3.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_MARIBOZU || cand3.type==CAND_SHORT) && 
         cand1.bodysize>cand2.bodysize && cand1.low<cand2.low && cand3.low>cand2.low && cand3.high<cand2.high)
    {
        if(_forex)
        {
            DrawSignal("Three Star in the South" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
        }
        else // other market
        {
            // opening inside the previous candlestick
            if(cand1.close<cand2.open && cand2.close<cand3.open)
            {
               DrawSignal("Three Star in the South" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Three White Soldiers
    // check direction of trend and direction of candlestick
    // check of "long" candlestick or "maribozu"
    // check of "long" candlestick and "maribozi"
    if(cand1.trend==DOWN && cand1.bull && cand2.bull && cand3.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) &&
         (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG))
    {
        if(_forex)
        {
            DrawSignal("Three White Soldiers" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
        }
        else // other market
        {
            // opening inside the previous candlestick
            if(cand1.close>cand2.open && cand2.close>cand3.open)
            {
                DrawSignal("Three White Soldiers" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Three Outside Up
    // check direction of trend and direction of candlestick
    // body of the second candlestick is bigger than that of the first one
    // the third day is closed higher than the second one
    if(cand1.trend==DOWN && !cand1.bull && cand2.trend==DOWN && cand2.bull && cand3.bull &&
         cand2.bodysize>cand1.bodysize && cand3.close>cand2.close)
    {
        if(_forex)
        {   // body of the first candlestick is inside of body of the second one
            if(cand1.close>=cand2.open && cand1.open<cand2.close)
            {
                DrawSignal("Three Outside Up" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
         else
        {
            // body of the first candlestick inside of body of the second candlestick
            if(cand1.close>cand2.open && cand1.open<cand2.close) 
            {
               DrawSignal("Three Outside Up" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Three Inside Up
    // check direction of trend and direction of candlestick
    // check of "long" first candle
    // body of the first candlestick is bigger than that of the second one
    // the third day is closed higher than the second one
    if(cand1.trend==DOWN && !cand1.bull && cand2.bull && cand3.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) &&
         cand1.bodysize>cand2.bodysize &&  cand3.close>cand2.close)
    {
        if(_forex)
        {
            // body of the second candlestick is inside of body of the first candlestick
            if(cand1.close<=cand2.open && cand1.close<=cand2.close && cand1.open>cand2.close)
            {
                DrawSignal("Three Inside Up" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
        else
        {  
            // body of the second candlestick is inside of body of the first one
            if(cand1.close<cand2.open && cand1.close<cand2.close && cand1.open>cand2.close)
            { 
               DrawSignal("Three Inside Up" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Tri Star
    // check direction of trend
    // check of Doji
    if(cand1.trend==DOWN && cand1.type==CAND_DOJI && cand2.type==CAND_DOJI && cand3.type==CAND_DOJI) 
    {
        if(_forex)
        {
            DrawSignal("Tri Star" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
        }
        else
        {
            // the second candlestick is on the other level
            if(cand2.open!=cand1.close && cand2.close!=cand3.open)
            {
               DrawSignal("Tri Star" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
            }
        }
    }

    // Unique Three River Bottom
    // check direction of trend and direction of candlestick
    // check of "long" candlestick or "maribozu" or the third day is short
    // body of the second candlestick is inside the first one, and its minimum is lower than the first one
    // the third candlestick is lower than the second one
    if(cand1.trend==DOWN && !cand1.bull && !cand2.bull && cand3.bull &&
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand3.type==CAND_SHORT &&
        cand2.open<cand1.open && cand2.close>cand1.close && cand2.low<cand1.low &&  cand3.close<cand2.close)
    {
        if(!_forex)
        {
            DrawSignal("Unique Three River Bottom" + TimeToString(TimeCurrent()),cand1, cand2, cand3, ColorBull);
        }
    }


    // Check of patterns with four candlesticks
    CANDLE_STRUCTURE cand4;
    if(!RecognizeCandle(PERIOD_CURRENT, 4, global.NO_OF_CANDLES, cand4)) return false;
    BullishReversals(cand1, cand2, cand3, cand4);

    return true;
}

// Function for checking possible reveasal to the upside -- 4 candlesticls
bool CCandlePatterns::BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4)
{
    // Concealing Baby Swallow
    // check direction of trend and direction of candlestick
    // check of "maribozu"
    // the third candlestick with a lower gap, maximum is inside the second candlestick
    // the fourth candlestick fully consumes the third one
    if(cand1.trend==DOWN && !cand1.bull && !cand2.bull && !cand3.bull && !cand4.bull &&
        cand1.type==CAND_MARIBOZU_LONG && cand2.type==CAND_MARIBOZU_LONG && cand3.type==CAND_SHORT &&
        cand3.open<cand2.close && cand3.high>cand2.close &&
        cand4.open>cand3.high && cand4.close<cand3.low) 
    {
        if(!_forex)// not forex
        {
             DrawSignal("Unique Three River Bottom" + TimeToString(TimeCurrent()),cand1, cand2, cand4, ColorBull);
        }
    }

    // Three-line strike
    // check direction of trend and direction of candlestick
    // check of "long" candlestick or "maribozu
    // check "long" candlestick and "maribozu"
    // closing of the second candlestick is above the first one,closing of the third one is above the second one; the fourth candlestick is closed below the first one
    if(cand1.trend==UPPER && cand1.bull && cand2.bull && cand3.bull && !cand4.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) &&
         (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) && 
         cand2.close>cand1.close && cand3.close>cand2.close && cand4.close<cand1.open)
    {
        if(_forex)
        {
            // the fourth candlestick is opened above or on the same level with the third one
            if(cand4.open>=cand3.close)
            {
                DrawSignal("Three-line strikes" + TimeToString(TimeCurrent()), cand1, cand3, cand4, ColorBull);
            }
        }
        else // other market
        {
            // the fourth candlestick is opened above the third one
            if(cand4.open>cand3.close) 
            {
               DrawSignal("Three-line strikes" + TimeToString(TimeCurrent()), cand1, cand3, cand4, ColorBull);
            }
        }
    }

    // Check of patterns with five candlesticks
    CANDLE_STRUCTURE cand5;
    if(!RecognizeCandle(PERIOD_CURRENT, 5, global.NO_OF_CANDLES, cand5)) return false;
    BullishReversals(cand1, cand2, cand3, cand4, cand5);

    return true;
}

// Function for checking possible reveasal to the upside -- 5 candlesticls
bool CCandlePatterns::BullishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4, CANDLE_STRUCTURE &cand5)
{
    // Breakaway
    // check direction of trend and direction of candlestick
    // check of "long" first candlestick
    // the second "candlestick" is "short" and is cut off the first one
    // the third and fourth candlesticks are "short"
    // the fifth one is "long", white and is closed inside the gap
    if(cand1.trend==DOWN && !cand1.bull && !cand2.bull && !cand4.bull && cand5.bull && 
        (cand1.type==CAND_LONG|| cand1.type==CAND_MARIBOZU_LONG) && 
         cand2.type==CAND_SHORT && cand2.open<cand1.close && 
         cand3.type==CAND_SHORT && cand4.type==CAND_SHORT && 
         (cand5.type==CAND_LONG || cand5.type==CAND_MARIBOZU_LONG) && cand5.close<cand1.close && cand5.close>cand2.open) 
    {
        if(!_forex)
        {
            DrawSignal("Breakaway" + TimeToString(TimeCurrent()), cand1, cand3, cand5, ColorBull);
        }
    }

    return true;
}

// Function for checking possible reversal to the downside -- I candlestick
bool CCandlePatterns::BearishReversals(CANDLE_STRUCTURE &cand1)
{
    // Hanging Man
    if(cand1.trend==UPPER && cand1.type==CAND_HAMMER)
    {
        DrawSignal("Hanging Man"+ TimeToString(TimeCurrent()),cand1, ColorBear);
    }

    // Check of patterns with two candlesticks
    CANDLE_STRUCTURE cand2;
    if(!RecognizeCandle(PERIOD_CURRENT, 2, global.NO_OF_CANDLES, cand2)) return false;
    BearishReversals(cand1, cand2);

    return true;
}

// Function for checking possible reveasal to the downside -- 2 candlesticls
bool CCandlePatterns::BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2)
{
    // Shooting Star
    if (cand1.trend==UPPER && cand2.trend==UPPER && cand2.type==CAND_INVERT_HAMMER) 
    {
        if(_forex)
        {
            if (cand1.close<= cand2.open) // close 1 is less than or equal to open 1
            {
               DrawSignal("Shooting Star" + TimeToString(TimeCurrent()), cand2, ColorBear);
            }
        }
         else
        {
            if (cand1.close < cand2.open && cand1.close < cand2.close) // 2 candlestick is cut off from 1
            {
               DrawSignal("Shooting Star" + TimeToString(TimeCurrent()), cand2, ColorBear);
            }
        } 
    }

    // Belt Hold
    // body of the first candlestick is lower than body of the second one; close price of the second candlestick is higher than that of the first one
    if (cand2.trend==UPPER && !cand2.bull && cand1.bull && cand2.type==CAND_MARIBOZU_LONG && cand1.bodysize<cand2.bodysize && cand2.close>cand1.close) 
    {
        if(!_forex)
        {
            DrawSignal("Belt Hold" + TimeToString(TimeCurrent()), cand2, ColorBear);
        }
    }

    // Engulfing
    // body of the third candlestick is bigger than that of the second one
    if (cand1.trend==UPPER && cand1.bull && cand2.trend==UPPER && !cand2.bull && cand1.bodysize<cand2.bodysize)
    {
        if(_forex)
        {   // body of the first candlestick is inside of body of the second one
            if(cand1.close<=cand2.open && cand1.open>cand2.close)
            {
                DrawSignal("Engulfing" + TimeToString(TimeCurrent()), cand2, ColorBear);
            }
        }
        else
        {
            // close 1 is lower or equal to open 2; or open 1 is higher or equal to close 2
            if(cand1.close<cand2.open && cand1.open>cand2.close) 
            {
                DrawSignal("Engulfing" + TimeToString(TimeCurrent()), cand2, ColorBear);
            }
        }
    }

    // Harami Cross
    // check of "long" candlestick and Doji
    if (cand1.trend==UPPER && cand1.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand2.type==CAND_DOJI)
    {
        if(_forex)
        {
            // Doji is inside of body of the first candlestick
            if(cand1.close>=cand2.open && cand1.close>=cand2.close && cand1.close>=cand2.close)
            {
                DrawSignal("Engulfing" + TimeToString(TimeCurrent()), cand2, ColorBear);
            }
        }
        else
        {
            // Doji is inside of body of the first candlestick
            if(cand1.close>cand2.open && cand1.close>cand2.close && cand1.open<cand2.close)
            {
                DrawSignal("Engulfing" + TimeToString(TimeCurrent()), cand2, ColorBear);
            }
        }
    }

    // Harami
    // check direction of trend and direction of candlestick
    // check of "long" first candlestick
    // the second candlestick is not Doji and body of the first candlestick is bigger than that of the second one
    if (cand1.trend==UPPER && cand1.bull && !cand2.bull && (cand1.type==CAND_LONG|| cand1.type==CAND_MARIBOZU_LONG) && cand2.type!=CAND_DOJI && cand1.bodysize>cand2.bodysize)
    {
        if(_forex)
        {
            // Doji is inside of body of the first candlestick
            if(cand1.close>=cand2.open && cand1.close>=cand2.close && cand1.close>=cand2.close)
            {
                DrawSignal("Harami" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
            }
        }
         else
        {
            // Doji is inside of body of the first candlestick
            if(cand1.close>cand2.open && cand1.close>cand2.close && cand1.open<cand2.close)
            {
               DrawSignal("Harami" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
            }
        }
    }

    // Doji Star
    // check direction of trend and direction of candlestick
    // check first "long" candlestick and 2 doji
    if (cand1.trend==UPPER && cand1.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && cand2.type==CAND_DOJI)
    {
        if(_forex)
        {
            // open price of Doji is higher or equal to close price of the first candlestick
            if(cand1.close<=cand2.open)
            {
                DrawSignal("Doji Star" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
            }
        }
        else
        {
            // body of Doji is cut off the body of the first candlestick
            if(cand1.close<cand2.open && cand1.close<cand2.close)
            {
                DrawSignal("Doji Star" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
            }
        }
    }

    // Dark Cloud Cover
    // check direction and direction of candlestick
    // check of "long" candlestick
    // close price of 2-nd candlestick is lower than the middle of the body of the 1-st one
    if (cand1.trend==UPPER && cand1.bull && cand2.trend==UPPER && !cand2.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) && cand2.close<(cand1.close+cand1.open)/2)
    {
        if(_forex)
        {
            if(cand1.close<=cand2.open && cand2.close>=cand1.open)
            {
                DrawSignal("Dark Cloud Cover" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
            }
        }
        else
        {
            if(cand1.high<cand2.open && cand2.close>=cand1.open)
            {
               DrawSignal("Dark Cloud Cover" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
            }
        }
    }    
    
    // Meeting Lines
    // check direction and direction of candlestick
    // check of "long" candlestick
    // close prices are equal, size of the first one is smaller than that of the second one, open price of the second one is higher than the maximum of the first one
    if(cand1.trend==UPPER && cand1.bull && cand2.trend==UPPER && !cand2.bull && (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) &&  cand1.close==cand2.close && cand1.bodysize<cand2.bodysize && cand1.high<cand2.open)
    {
        if(!_forex)
        {
            DrawSignal("Meeting Lines" + TimeToString(TimeCurrent()), cand1, cand2, ColorBear);
        }
    }
    
    // Check of patterns with three candlesticks
    CANDLE_STRUCTURE cand3;
    if(!RecognizeCandle(PERIOD_CURRENT, 3, global.NO_OF_CANDLES, cand3)) return false;
    BearishReversals(cand1, cand2, cand3);
    
    return true;
}

// Function for checking possible reveasal to the downside -- 3 candlesticls
bool CCandlePatterns::BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3)
{
    // The Abandoned Baby
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // check if the second candlestick is Doji
    // the third one is closed inside of body of the second one
    if(cand1.trend==UPPER && cand1.bull && cand3.trend==UPPER && !cand3.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) &&
         cand2.type==CAND_DOJI && cand3.close>cand1.open && cand3.close<cand1.close)
    {
        if(!_forex)
        {
            // gap between candlesticks
            if(cand1.high<cand2.low && cand3.high<cand2.low)
            {
                DrawSignal("Abandoned Baby" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Evening star
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // check of "short" candlestick
    // the third candlestick is closed inside of body of the first one
    if(cand1.trend==UPPER && cand1.bull && cand3.trend==UPPER && !cand3.bull && 
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) &&
        cand2.type==CAND_SHORT &&  cand3.close<cand1.close && cand3.close>cand1.open) 
    {
        if(_forex) // forex
        {
            // open price of the second candlestick is higher than that of the first one
            if(cand2.open>=cand1.close)
            {
                DrawSignal("Evening star" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
         else // other market
        {
            // gap between candlesticks
            if(cand2.open>cand1.close && cand2.close>cand1.close)
            {
                DrawSignal("Evening star" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Evening Doji Star
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // check of "doji"
    // the third candlestick is closed inside of body of the first one
    if(cand1.trend==UPPER && cand1.bull && cand3.trend==UPPER && !cand3.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) &&
         cand2.type==CAND_DOJI && 
         cand3.close<cand1.close && cand3.close>cand1.open) 
    {
        if(_forex)// if it's forex
        {
            // open price of Doji is higher or equal to close price of the first candlestick
            if(cand2.open>=cand1.close)
            {
                DrawSignal("Evening Doji Star" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
        else // other market
        {
            // gap between Doji and the first candlestick
            // check of close 2 and open 3
            if(cand2.open>cand1.close)
            {
               DrawSignal("Evening Doji Star" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Upside Gap Two Crows
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // distance of the second and third candlesticks from the first one
    // the third candlestick absorbs the second one
    if(cand1.trend==UPPER && cand1.bull && cand2.trend==UPPER && !cand2.bull && cand3.trend==UPPER && !cand3.bull &&
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG)  && 
        cand1.close<cand2.close && cand1.close<cand3.close && cand2.open<cand3.open && cand2.close>cand3.close) 
    {
        if(!_forex)
        {
            DrawSignal("Upside Gap Two Crows" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
        }
    }

    // Two Crows
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // distance between the second and first candlesticks
    // the third candlestick is opened higher than the close price of the second one
    // the third candlestick is closed below the close price of the first one
    if(cand1.trend==UPPER && cand1.bull && cand2.trend==UPPER && !cand2.bull && cand3.trend==UPPER && !cand3.bull &&
         (cand1.type==CAND_LONG|| cand1.type==CAND_MARIBOZU_LONG) &&(cand3.type==CAND_LONG|| cand3.type==CAND_MARIBOZU_LONG) && 
         cand1.close<cand2.close &&  cand3.open>cand2.close && cand3.close<cand1.close) 
    {
        if(!_forex)
        {
            DrawSignal("Two Crows" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
        }
    }

    // Deliberation
    // check direction of trend and direction of candlestick
    // check of "long" candlestick
    // the third candlestick is the spin or start
    if(cand1.trend==UPPER && cand1.bull && cand2.bull && cand3.bull &&
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) && 
        (cand3.type==CAND_SPIN_TOP || cand3.type==CAND_SHORT))
    {
        if(_forex)
        {
            DrawSignal("Deliberation" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
        }
        else // other market
        {
            // opening inside the previous candlestick
            // check of close 2 and open 3
            if(cand1.close>cand2.open && cand2.close<=cand3.open)
            {
                DrawSignal("Deliberation" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Three Black Crows
    // check direction of trend and direction of candlestick
    // check of "long" candlestick or "maribozu"
    // check "long" candlestick and "maribozu"
    // opening inside the previous candlestick
    if(cand1.trend==UPPER && !cand1.bull && !cand2.bull && !cand3.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) && 
         (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) && 
         cand1.close<cand2.open  &&  cand2.close<cand3.open) 
    {
        if(!_forex)
        {
            DrawSignal("Three Black Crows" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
        }
    }

    // Three Outside Down
    // check direction of trend and direction of candlestick
    // body of the second candlestick is bigger than that of the first one
    // the third day is closed lower than the second one
    if(cand1.trend==UPPER && cand1.bull && cand2.trend==UPPER && !cand2.bull && !cand3.bull &&
        cand2.bodysize>cand1.bodysize && cand3.close<cand2.close)
    {
        if(_forex)
        {
            // body of the first candlestick is inside of body of the second one
            if(cand1.close<=cand2.open && cand1.open>cand2.close)
            {
                DrawSignal("Three Outside Down" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
        else
        {
            // body of the first candlestick is inside of body of the second one
            if(cand1.close<cand2.open && cand1.open>cand2.close)
            {
               DrawSignal("Three Outside Down" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Three Inside Down
    // check direction of trend and direction of candlestick
    // check of "long" first candle
    // body of the first candlestick is bigger than that of the second one
    // the third day is closed lower than the second one
    if(cand1.trend==UPPER && cand1.bull && !cand2.bull && !cand3.bull &&
        (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) &&
        cand1.bodysize>cand2.bodysize &&  cand3.close<cand2.close)
    {
        if(_forex)
        {
            // inside of body of the first candlestick
            if(cand1.close>=cand2.open && cand1.close>=cand2.close && cand1.close>=cand2.close)
            {
                DrawSignal("Three Inside Down" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
        else
        {
            // inside of body of the first candlestick
            if(cand1.close>cand2.open && cand1.close>cand2.close && cand1.open<cand2.close)
            {
               DrawSignal("Three Inside Down" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Tri Star
    // check direction of trend
    // check of Doji
    if(cand1.trend==UPPER &&  cand1.type==CAND_DOJI && cand2.type==CAND_DOJI && cand3.type==CAND_DOJI) 
    {
        if(_forex)
        {
            DrawSignal("Tri Star" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
        }
        else
        {
            // the second candlestick is on the other level
            if(cand2.open!=cand1.close && cand2.close!=cand3.open)
            {
               DrawSignal("Tri Star" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }

    // Identical Three Crows
    // check direction of trend and direction of candlestick
    // check of "long" candlestick or "maribozu"
    // check of "long" candlestick and "maribozi"
    if(cand1.trend==UPPER && !cand1.bull && !cand2.bull && !cand3.bull && 
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) &&
         (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG))
    {
        if(_forex)// if it's forex
        {
            DrawSignal("Identical Three Crows" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
        }
        else // other market
        {
            // open price is smaller or equal to close price of the previous candlestick
            if(cand1.close>=cand2.open && cand2.close>=cand3.open)
            {
               DrawSignal("Identical Three Crows" + TimeToString(TimeCurrent()), cand1, cand2, cand3, ColorBear);
            }
        }
    }


    // Check of patterns with four candlesticks
    CANDLE_STRUCTURE cand4;
    if(!RecognizeCandle(PERIOD_CURRENT, 4, global.NO_OF_CANDLES, cand4)) return false;
    BearishReversals(cand1, cand2, cand3, cand4);

    return true;
}

// Function for checking possible reveasal to the downside -- 4 candlesticls
bool CCandlePatterns::BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4)
{

    // Three-line strike
    // check direction of trend and direction of candlestick  
    // check of "long" candlestick or "maribozu"
    // check "long" candlestick and "maribozu"
    // closing of the second one is below the first, third is below the second, fourth is closed above the first one
    if(cand1.trend==DOWN && !cand1.bull && !cand2.bull && !cand3.bull && cand4.bull &&
         (cand1.type==CAND_LONG || cand1.type==CAND_MARIBOZU_LONG) && (cand2.type==CAND_LONG || cand2.type==CAND_MARIBOZU_LONG) &&
         (cand3.type==CAND_LONG || cand3.type==CAND_MARIBOZU_LONG) && 
         cand2.close<cand1.close && cand3.close<cand2.close && cand4.close>cand1.open)
    {
        if(_forex)
        {
            // the fourth candlestick is opened below or on the same level with the third one
            if(cand4.open<=cand3.close)
            {
                DrawSignal("Three-line strikes" + TimeToString(TimeCurrent()), cand1, cand3, cand4, ColorBear);
            }
        }
        else // other market
        {
            // the fourth candlestick is opened below the third one
            if(cand4.open<cand3.close)
            {
               DrawSignal("Three-line strikes" + TimeToString(TimeCurrent()), cand1, cand3, cand4, ColorBear);
            }
        }
    }

    // Check of patterns with five candlesticks
    CANDLE_STRUCTURE cand5;
    if(!RecognizeCandle(PERIOD_CURRENT, 5, global.NO_OF_CANDLES, cand5)) return false;
    BearishReversals(cand1, cand2, cand3, cand4, cand5);
    return true;
}

// Function for checking possible reveasal to the downside -- 5 candlesticls
bool CCandlePatterns::BearishReversals(CANDLE_STRUCTURE &cand1, CANDLE_STRUCTURE &cand2, CANDLE_STRUCTURE &cand3, CANDLE_STRUCTURE &cand4, CANDLE_STRUCTURE &cand5)
{
    // Breakaway, the bearish model
    // check direction of trend and direction of candlestick
    // check of "long" first candlestick
    // the second "candlestick" is "short" and is cut off the first one
    // the third and fourth candlesticks are "short"
    // the fifth candlestick is "long" and is closed inside the gap
    if(cand1.trend==UPPER && cand1.bull && cand2.bull && cand4.bull && !cand5.bull &&
        (cand1.type==CAND_LONG|| cand1.type==CAND_MARIBOZU_LONG) &&  
        cand2.type==CAND_SHORT && cand2.open<cand1.close && 
        cand3.type==CAND_SHORT && cand4.type==CAND_SHORT && 
        (cand5.type==CAND_LONG || cand5.type==CAND_MARIBOZU_LONG) && cand5.close>cand1.close && cand5.close<cand2.open) 
    {
        if(!_forex)
        {
            DrawSignal("Breakaway" + TimeToString(TimeCurrent()), cand1, cand2, cand5, ColorBear);
        }
    }
    return true;
}

// Function for checking possible continuation
bool CCandlePatterns::ContinuesPattern(int number_of_candles)
{
   
    return true;
}

// Draw Signal
void CCandlePatterns::DrawSignal(string objname, CANDLE_STRUCTURE &cand, color Col)
  {
   string objtext=objname+"text";
   if(ObjectFind(0,objtext)>=0) ObjectDelete(0,objtext);
   if(ObjectFind(0,objname)>=0) ObjectDelete(0,objname);

    if(Col==ColorBull)
    {
        ObjectCreate(0,objname,OBJ_ARROW_BUY,0,cand.time,cand.low);
        ObjectSetInteger(0,objname,OBJPROP_ANCHOR,ANCHOR_TOP);

        ObjectCreate(0,objtext,OBJ_TEXT,0,cand.time,cand.low);
        ObjectSetInteger(0,objtext,OBJPROP_ANCHOR,ANCHOR_LEFT);
        ObjectSetDouble(0,objtext,OBJPROP_ANGLE,-90);
    }
    else
    {
        ObjectCreate(0,objname,OBJ_ARROW_SELL,0,cand.time,cand.high);
        ObjectSetInteger(0,objname,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
      
        ObjectCreate(0,objtext,OBJ_TEXT,0,cand.time,cand.high);
        ObjectSetInteger(0,objtext,OBJPROP_ANCHOR,ANCHOR_LEFT);
        ObjectSetDouble(0,objtext,OBJPROP_ANGLE,90);
    }
    ObjectSetInteger(0,objname,OBJPROP_COLOR,Col);
    ObjectSetInteger(0,objname,OBJPROP_BACK,false);
    ObjectSetString(0,objname,OBJPROP_TEXT, objname);
   
    ObjectSetInteger(0,objtext,OBJPROP_COLOR,Col);
    ObjectSetString(0,objtext,OBJPROP_FONT,"Tahoma");
    ObjectSetInteger(0,objtext,OBJPROP_FONTSIZE, 10);
    ObjectSetString(0,objtext,OBJPROP_TEXT,"    " + objname);
}

// Draw Signal
void CCandlePatterns::DrawSignal(string objname,CANDLE_STRUCTURE &cand1,CANDLE_STRUCTURE &cand2,color Col)
  {
    string objtext=objname+"text";
    double price_low=MathMin(cand1.low,cand2.low);
    double price_high=MathMax(cand1.high,cand2.high);

    if(ObjectFind(0,objtext)>=0) ObjectDelete(0,objtext);
    if(ObjectFind(0,objname)>=0) ObjectDelete(0,objname);

    ObjectCreate(0,objname,OBJ_RECTANGLE,0,cand1.time,price_low,cand2.time,price_high);
    if(Col==ColorBull)
    {
        ObjectCreate(0,objtext,OBJ_TEXT,0,cand1.time,price_low);
        ObjectSetInteger(0,objtext,OBJPROP_ANCHOR,ANCHOR_LEFT);
        ObjectSetDouble(0,objtext,OBJPROP_ANGLE,-90);
    }
    else
    {

        ObjectCreate(0,objtext,OBJ_TEXT,0,cand1.time,price_high);
        ObjectSetInteger(0,objtext,OBJPROP_ANCHOR,ANCHOR_LEFT);
        ObjectSetDouble(0,objtext,OBJPROP_ANGLE,90);
    }
    ObjectSetInteger(0,objname,OBJPROP_COLOR,Col);
    ObjectSetInteger(0,objname,OBJPROP_BACK,false);
    ObjectSetString(0,objname,OBJPROP_TEXT, objname);

    ObjectSetInteger(0,objtext,OBJPROP_COLOR,Col);
    ObjectSetString(0,objtext,OBJPROP_FONT,"Tahoma");
    ObjectSetInteger(0,objtext,OBJPROP_FONTSIZE, 10);
    ObjectSetString(0,objtext,OBJPROP_TEXT,"    " + objname);
}

// Draw Signal
void CCandlePatterns::DrawSignal(string objname,CANDLE_STRUCTURE &cand1,CANDLE_STRUCTURE &cand2,CANDLE_STRUCTURE &cand3,color Col)
{
    string objtext=objname+"text";
    double price_low=MathMin(cand1.low,MathMin(cand2.low,cand3.low));
    double price_high=MathMax(cand1.high,MathMax(cand2.high,cand3.high));

    if(ObjectFind(0,objtext)>=0) ObjectDelete(0,objtext);
    if(ObjectFind(0,objname)>=0) ObjectDelete(0,objname);

    ObjectCreate(0,objname,OBJ_RECTANGLE,0,cand1.time,price_low,cand3.time,price_high);
    if(Col==ColorBull)
    {
        ObjectCreate(0,objtext,OBJ_TEXT,0,cand3.time,price_low);
        ObjectSetInteger(0,objtext,OBJPROP_ANCHOR,ANCHOR_LEFT);
        ObjectSetDouble(0,objtext,OBJPROP_ANGLE,-90);
    }
    else
    {
        ObjectCreate(0,objtext,OBJ_TEXT,0,cand3.time,price_high);
        ObjectSetInteger(0,objtext,OBJPROP_ANCHOR,ANCHOR_LEFT);
        ObjectSetDouble(0,objtext,OBJPROP_ANGLE,90);
    }
    ObjectSetInteger(0,objname,OBJPROP_COLOR,Col);
    ObjectSetInteger(0,objname,OBJPROP_BACK,false);
    ObjectSetInteger(0,objname,OBJPROP_WIDTH,2);
    ObjectSetString(0,objname,OBJPROP_TEXT, objname);

    ObjectSetInteger(0,objtext,OBJPROP_COLOR,Col);
    ObjectSetString(0,objtext,OBJPROP_FONT,"Tahoma");
    ObjectSetInteger(0,objtext,OBJPROP_FONTSIZE, 10);
    ObjectSetString(0,objtext,OBJPROP_TEXT,"    " + objname);
}
  