#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <myIncludes\NDS\Definitions.mqh>

class CCandleTypes 
{
    private:

    public:
        void        CCandleTypes();
        void        ~CCandleTypes();
        bool        RecognizeCandle(ENUM_TIMEFRAMES period, int start_position, int aver_period, CANDLE_STRUCTURE &res);
};


  // constructor
void CCandlePatterns::CCandleTypes(void) {};

// deconstructor
void CCandlePatterns::~CCandleTypes(void) {};

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
