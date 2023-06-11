#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+

#include <Trade\DealInfo.mqh>
#include <myIncludes\NDS\PriceAction.mqh>
#include <myIncludes\NDS\Trade.mqh>
#include <myIncludes\NDS\MoneyManagement.mqh>
#include <myIncludes\NDS\CandlePatterns.mqh>

//+------------------------------------------------------------------+
//| Class Objects                                                    |
//+------------------------------------------------------------------+
CDealInfo m_deal;             // object of CDealInfo class
CPriceAction pa;              // object of CPriceAction class
Trade trade;                  // object of Trade class
CMoneyManagment mMgt;         // object of CMoneyManagment class
CCandlePatterns cPtns;        // object of CMoneyManagment class


//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+

input group          "General"
input long           InputMagicNumber       = 43567;                // magic number

input group          "Trade Management"
input int            InputStopLoss          = 400;                  // default stop loss in points
input double         InputTakeProfit        = 3.0;                  // take profit: percentage of stop loss distance

input group          "Risk Management"
input double         InputMaxEquityDrawdown = 5;                    // maximum equity drawdown in percent
input double         InputMaxEquityProft    = 6;                    // maximum equity profit in percent
input ENUM_LOT_MODE  InputLotMode           = LOT_MODE_PCT_ACCOUNT; // lot mode
input double         InputVolume            = 1;                    // lots / money / percent
input int            InputMaxLossPerDay     = 2;                    // maximum loss per day
input bool           InputPullbackRetest    = false;                // maximum loss per day
input bool           InputLiveMarket        = false;                // live/backtest data

input group          "Advanced Equity Monitoring Module"
input bool           InputSlopeDetection    = false;
input int            InputLossStreakCounter = 0;

//+------------------------------------------------------------------+
//|  Global Variables                                                |
//+------------------------------------------------------------------+
MqlTick     previous_tick;              // tick object
MqlTick     current_tick;               // tick object
datetime    open_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // check user inputs
    if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;

   // set magic number
   trade.SetMagicNumber(InputMagicNumber);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{ 

}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

    // get current tick
    previous_tick = current_tick; 
    SymbolInfoTick(_Symbol, current_tick);

   // high timeframe 
   int h_bars = iBars(_Symbol, pa.timeframe.HIGH_TIMEFRAME);
   if (global.HIGH_BARS != h_bars && ulong(TimeCurrent() - iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0)) <= 60) { 
      global.HIGH_BARS = h_bars;

      // reset all 
      if (trade.CountOpenPositions(InputMagicNumber) == 0) resetEntry();
      trade.DeletePendingOrders(InputMagicNumber);
      pa.Init(InputLiveMarket);
   }

    // low timeframe
   int l_bars = iBars(_Symbol, PERIOD_CURRENT);
   if (global.LOW_BARS != l_bars && global.FIRST_CANDLE) {
      global.NO_OF_CANDLES++;
      global.LOW_BARS = l_bars;
   }

   // exit if an entry bias is not set
   if(pa.entry_bias == NO_ENTRY) return;

   // reversal candle patterns
   cPtns.ReversalPatterns(pa.prev_candle.bull);

   if (pa.entry_bias != NO_ENTRY && pa.prev_candle.bull) {
      if (current_tick.ask < pa.retracement.PRICE_ONE && current_tick.ask > pa.retracement.PRICE_FOUR){
         if (current_tick.ask < pa.stop_price) {
            pa.stop_price = current_tick.ask;
            pa.DrawLine("SL", OBJ_TREND, C'248,70,70', iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0) - 1, pa.stop_price, iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(pa.timeframe.HIGH_TIMEFRAME), pa.stop_price, true);
            pa.WriteText("SL", iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0) - 1, pa.stop_price, C'248,70,70', "SL", true);
         }
      }
   }

   if (pa.entry_bias != NO_ENTRY && !pa.prev_candle.bull) {
      if (current_tick.bid > pa.retracement.PRICE_ONE && current_tick.ask < pa.retracement.PRICE_FOUR){
         if (current_tick.bid > pa.stop_price) {
            pa.stop_price = current_tick.bid;
            pa.DrawLine("SL", OBJ_TREND, C'248,70,70', iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0) - 1, pa.stop_price, iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0) + PeriodSeconds(pa.timeframe.HIGH_TIMEFRAME), pa.stop_price, true);
            pa.WriteText("SL", iTime(_Symbol, pa.timeframe.HIGH_TIMEFRAME, 0) - 1, pa.stop_price, C'248,70,70', "SL", true);
         } 
      }
   }
   
   // cancel orders
   CancelOrders();

   // close open positions
   ClosePositions();

   /**
    *  ENTRY CONDITIONS 
    * 1. Bias is set by previous high timeframe candle - momentum to the upside/downside - possible entry price at the HIGH
    * 2. There is a pullback wick on the current high timeframe and the candle is now facing the same trend - possible entry price at the direction change back.
    * 3. Check lower time frame for entry, stop and take profit prices
    * 4. For trade to be considered, the pullback has to been between fibonacci retracement level one and 4 - possible stop loss at a Fibonacci level
    * 5. Use only pending orders(SELL/BUY STOPS). No instant orders
    * 6. Use reversal candlestick patterns confirm possible pullback and set stoploss and take profit
    * */
   
   // place order
   PlaceOrder(); 

   // tigger stop loss update once current bid/ask is 10pips away from take profit
   // trade.UpdateStopLoss(MagicNumber, pa.current_tick.bid, pa.current_tick.ask);
 
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
   //--- get transaction type as enumeration value
   ENUM_TRADE_TRANSACTION_TYPE type = trans.type;
   //--- if transaction is result of addition of the transaction in history
   if(type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
         m_deal.Ticket(trans.deal);
      else
      {
         Print(__FUNCTION__," > ERROR: HistoryDealSelect(", trans.deal ,")");
         return;
      }

      long reason = -1;
      if(!m_deal.InfoInteger(DEAL_REASON, reason))
      {
         Print(__FUNCTION__," > ERROR: InfoInteger(", DEAL_REASON ," ", reason ,")");
         return;
      }
      if((ENUM_DEAL_REASON)reason == DEAL_REASON_SL || (ENUM_DEAL_REASON)reason == DEAL_REASON_TP) 
      {
         resetEntry();
      }   
   }
}


//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+

// validate input fields
bool ValidateInputs()
{

   if(InputMagicNumber <= 0) 
   {
      Alert("Magic Number <= 0");
      return false;
   }
   if(InputLotMode == LOT_MODE_FIXED && (InputVolume <= 0 || InputVolume > 10)) 
   {
      Alert("volume must be > 0 and < 10");
      return false;
   }
   if(InputLotMode == LOT_MODE_MONEY && (InputVolume <= 0 || InputVolume > 1000)) 
   {
      Alert("balance must be > 0 and < 1000");
      return false;
   }
   if(InputLotMode == LOT_MODE_PCT_ACCOUNT && (InputVolume <= 0 || InputVolume > 5)) 
   {
      Alert("lot % must be > 0 and < 5");
      return false;
   }
   if(InputStopLoss <= 0 || InputStopLoss > 400) 
   {
      Alert("Stop loss must be > 0 and <= 400");
      return false;
   }
   if(InputTakeProfit <= 0 || InputTakeProfit > 5) 
   {
      Alert("take profit must be > 0 and <= 5");
      return false;
   }
   if(InputMaxEquityDrawdown < 3 || InputMaxEquityDrawdown > 12) 
   {
      Alert("max equity drawdown must be >= 3 and <= 12");
      return false;
   }
   if(InputMaxEquityProft < 3 || InputMaxEquityProft > 15) 
   {
      Alert("max equity profit must be > 3 and <= 12");
      return false;
   }
   if(InputMaxLossPerDay < 1 || InputMaxLossPerDay > 3) 
   {
      Alert("max loss per day must be >= 1 and <= 3");
      return false;
   }
   return true;
}


void PlaceOrder() 
{
   double lot = InputVolume;
 
   // open long position
   if (global.long_position_flag && trade.CountOpenPositions(InputMagicNumber) == 0 && trade.CountPendingOrders(InputMagicNumber) == 0 && open_time != iTime(_Symbol, PERIOD_CURRENT, 0)) 
   {
      open_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      // no instant entry
      if (current_tick.ask >= pa.entry_price) return;
      // order long entry
      double slDistance = mMgt.StopPoints(pa.stop_price, pa.entry_price);
      if(!mMgt.VolumeManagement(slDistance, lot, InputLotMode, ORDER_TYPE_BUY_STOP, pa.entry_price))
      {
         Print(PREFIX, "Error calculating volume");
         return;
      }
      trade.OpenPendingOrder(ORDER_TYPE_BUY_STOP, lot, pa.entry_price, slDistance, slDistance * InputTakeProfit);
      pa.entry_bias = NO_ENTRY;
   }

   // open short position 
   if (global.short_position_flag && trade.CountOpenPositions(InputMagicNumber) == 0 && trade.CountPendingOrders(InputMagicNumber) == 0 && open_time != iTime(_Symbol, PERIOD_CURRENT, 0)) 
   {
      open_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      // no instant entry
      if (current_tick.bid <= pa.entry_price) return;
      // order short entry
      double slDistance = mMgt.StopPoints(pa.stop_price, pa.entry_price);
      if(!mMgt.VolumeManagement(slDistance, lot, InputLotMode, ORDER_TYPE_SELL_STOP, pa.entry_price))
      {
         Print(PREFIX, "Error calculating volume");
         return;
      }
      trade.OpenPendingOrder(ORDER_TYPE_SELL_STOP, lot, pa.entry_price, slDistance, slDistance * InputTakeProfit);
      pa.entry_bias = NO_ENTRY;
   }
}

// close positions
void ClosePositions() {


   if (trade.CountOpenPositions(InputMagicNumber) == 0) return;

   if (!global.long_position_flag && !global.short_position_flag) return;

   datetime hours[];
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   datetime openTime = (datetime) PositionGetInteger(POSITION_TIME);
   int countHours = CopyTime(_Symbol, PERIOD_H1, openTime, TimeCurrent(), hours);

   // close position if in profit and open time is more than 8 hours
   if(countHours >= 8 && profit > 0)
   {
      trade.ClosePositions(InputMagicNumber);
      resetEntry();
   }

   // close position if an opposite bias is set
}

// Cancel open orders
void CancelOrders() {

   bool close_order = false;
   if (trade.CountPendingOrders(InputMagicNumber) > 0) 
   {

      // new entry bias is set
      if(pa.entry_bias != NO_ENTRY) close_order = true;

      // pull back wick continues backward
      // ::TODO:: change to cancel order if pending order stop loss is crossed. 

      //close all open orders
      if(close_order) {
         close_order = !close_order;
         trade.DeletePendingOrders(InputMagicNumber);
         resetEntry();
      }
   
   }
}

void resetEntry() {
   pa.entry_bias = NO_ENTRY;
   global.long_position_flag = false;
   global.short_position_flag = false;
}