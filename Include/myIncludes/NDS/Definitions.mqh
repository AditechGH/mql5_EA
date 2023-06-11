#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Define                                                           |
//+------------------------------------------------------------------+
//--- @file [Global] 
#define PREFIX __FILE__," "__FUNCTION__," Line:",__LINE__, " >==> "

//--- @file [MoneyManagement.mqh] 
#define MAX_EQUITY_PROFIT 15                // exit EA if profit reaches the percentage 
#define MAX_EQUITY_DRAWDWON 12              // exit EA if loss reaches the percentage
#define MAX_SPREAD 100                      // max spread
#define MIN_DISTANCE 350                    // min distance
#define MAX_DISTANCE 500                    // min distance


//--- @file [Trade.mqh] 
//+------------------------------------------------------------------+
//| @enum EXECTION TYPE                                              |
//+------------------------------------------------------------------+
enum EXECUTION_TYPE
{
    INSTANT,                                // instant order
    PENDING,                                // pending order
};

//--- @file [MoneyManagement.mqh]  
//+------------------------------------------------------------------+
//|  @enum LOT MODE                                                  |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
{
    LOT_MODE_FIXED,                         // fixed lot
    LOT_MODE_MONEY,                         // lots based on money
    LOT_MODE_PCT_ACCOUNT                    // lots based on % of account
};

//--- @file [PriceAction.mqh]  
//+------------------------------------------------------------------+
//|  @enum ENTRY BIAS                                                |
//+------------------------------------------------------------------+
enum ENTRY_BIAS
{
    NO_ENTRY,                               // no entry
    LONG_ENTRY,                             // long entry
    SHORT_ENTRY                             // short entry
};

//--- @file [CandleTypes.mqh]  
//+------------------------------------------------------------------+
//|  @enum CANDLESTICK TYPE                                          |
//+------------------------------------------------------------------+
enum TYPE_CANDLESTICK
{
    CAND_NONE,                              // Unknown
    CAND_MARIBOZU,                          // Maribozu
    CAND_MARIBOZU_LONG,                     // Maribozu long
    CAND_DOJI,                              // Doji
    CAND_SPIN_TOP,                          // Spins
    CAND_HAMMER,                            // Hammer
    CAND_HAMMER_LONG,                       // Hammer
    CAND_INVERT_HAMMER,                     // Inverted Hammer long
    CAND_INVERT_HAMMER_LONG,                // Inverted Hammer long
    CAND_LONG,                              // Long
    CAND_SHORT,                             // Short
    CAND_STAR                               // Star
};

//--- @file [CandleTypes.mqh]    
//+------------------------------------------------------------------+
//|  @enum TYPE_TREND                                                |
//+------------------------------------------------------------------+
enum TYPE_TREND
{
    UPPER,                                  // Ascending
    DOWN,                                   // Descending
    LATERAL                                 // Lateral
};

//--- @file [PriceAction.mqh]  
//+------------------------------------------------------------------+
//|  @struct TIMEFRAME                                               |
//+------------------------------------------------------------------+
struct TIMEFRAME
{
    ENUM_TIMEFRAMES  HIGH_TIMEFRAME;        // default high timeframe
    ENUM_TIMEFRAMES  LOW_TIMEFRAME;         // default low timeframe

    TIMEFRAME(): HIGH_TIMEFRAME(PERIOD_H4), LOW_TIMEFRAME(PERIOD_M5) {};
};

//--- @file [PriceAction.mqh]  
//+------------------------------------------------------------------+
//|  @struct RETRACEMENT LEVELS                                      |
//+------------------------------------------------------------------+
struct RETRACEMENT
{
    const double    LEVEL_ONE;              // red retracement level (0.236)
    const double    LEVEL_TWO;              // gold retracement level (0.382)
    const double    LEVEL_THREE;            // green retracement level (0.5)
    const double    LEVEL_FOUR;             // green retracement level (0.618)
    const double    LEVEL_FIVE;             // green retracement level (0.786)

    double          PRICE_ONE;              // price at level one
    double          PRICE_TWO;              // price at level two
    double          PRICE_THREE;            // price at level three
    double          PRICE_FOUR;             // price at level four
    double          PRICE_FIVE;             // price at level five

    RETRACEMENT(): LEVEL_ONE(0.236), LEVEL_TWO(0.382), LEVEL_THREE(0.5), LEVEL_FOUR(0.618), LEVEL_FIVE(0.786) {};
};

//--- @file [CandlePatterns.mqh]    
//+------------------------------------------------------------------+
//| @struct CANDLE_STRUCTURE                                               |
//+------------------------------------------------------------------+
struct CANDLE_STRUCTURE
{
    double           open,high,low,close;   // OHLC
    datetime         time;                  // Time
    TYPE_TREND       trend;                 // Trend
    bool             bull;                  // Bullish candlestick
    double           bodysize;              // Size of body
    TYPE_CANDLESTICK type;                  // Type of candlestick
};

//--- @file [global]    
//+------------------------------------------------------------------+
//| @struct GLOBAL VARIABLES                                         |
//+------------------------------------------------------------------+
struct GLOBAL
{
    bool             FIRST_CANDLE;          // first candle of the week
    bool             LIVE_MARKET;           // Live/Demo data
    int              NO_OF_CANDLES;         // Number of candles
    int              HIGH_BARS;             // High timeframe open candle
    int              LOW_BARS;              // Low timeframe open candle
    bool             long_position_flag;
    bool             short_position_flag;   
};

GLOBAL global = { false, false, 0, 0, 0 };