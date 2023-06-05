#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <myIncludes\NDS\Definitions.mqh>

//+------------------------------------------------------------------+
//|  Class Trade                                                     |
//+------------------------------------------------------------------+
class Trade
  {

    private:
        CTrade      trade;
        bool        CheckOrder(long &magic_number, ulong &ticket, int index, EXECUTION_TYPE order_type);
        bool        ComputePrice(ENUM_ORDER_TYPE order_type, double price, double stop_points, double profit_points, double &stop_loss, double &take_profit);
        bool        NormalizePrice(double price, double &normalizedprice);

    public: 
        void        Trade();
        void        ~Trade();
        void        SetMagicNumber(ulong magic_number);

        bool        OpenPosition(ENUM_ORDER_TYPE order_type, double volume, double price, double stop_points = 0, double profit_points = 0, string comment = NULL);
        bool        ClosePositions(ulong magic_number);
        int         CountOpenPositions(ulong magic_number);

        bool        OpenPendingOrder(ENUM_ORDER_TYPE order_type, double volume, double price, double stop_points = 0, double profit_points = 0, string comment = NULL);      
        bool        DeletePendingOrders(ulong magic_number);
        int         CountPendingOrders(ulong magic_number);
        void        UpdateStopLoss(ulong magic_number, double bid_price, double ask_price);


  };


  // constructor
void Trade::Trade(void) {};

// deconstructor
void Trade::~Trade(void) {};



// check open position
bool Trade::CheckOrder(long &magic_number, ulong &ticket, int index, EXECUTION_TYPE type) 
{
 
    // get position/order ticket
    ticket = (type == INSTANT) ? PositionGetTicket(index) : OrderGetTicket(index);
    if(ticket <= 0) 
    {
        Print(PREFIX, "Error: Failed to get ", type == INSTANT ? "position" : "order" ," ticket");
        return false;
    }

    // select position by ticket
    bool selected_ticket = (type == INSTANT) ? PositionSelectByTicket(ticket) : OrderSelect(ticket);
    if(!selected_ticket) 
    {
        Print(PREFIX, "Error: Failed to select ", type == INSTANT ? "position" : "order"  ,"  by ticket");
        return false;
    }

    // fetch magic number and assign it to the magic variable
    bool magic = (type == INSTANT) ? PositionGetInteger(POSITION_MAGIC, magic_number) : OrderGetInteger(ORDER_MAGIC, magic_number);
    if(!magic) 
    {
        Print(PREFIX, "Error: Failed to get ", type == INSTANT ? "position" : "order" ," magic number!");
        return false;
    }

    return true;
}
 
// compute order stop loss and take profit
bool Trade::ComputePrice(ENUM_ORDER_TYPE order_type, double price, double stop_points, double profit_points, double &stop_loss, double &take_profit) {

    // set values
    stop_loss = 0;
    take_profit = 0;

    // check for order type
    if (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT )
    {
       if(stop_points > 0)  stop_loss = price - (stop_points * _Point);
       if(profit_points > 0) take_profit = price + (profit_points * _Point);
    }
    else if (order_type == ORDER_TYPE_SELL || order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)
    {
        if(stop_points > 0) stop_loss = price + (stop_points * _Point);
        if(profit_points > 0) take_profit = price - (profit_points * _Point);
    }
    else
    {
        return false;
    }
    if(!NormalizePrice(stop_loss, stop_loss)) return false;
    if(!NormalizePrice(take_profit, take_profit))  return false;

    if(stop_loss <= 0 || take_profit <= 0) {
        Print(PREFIX, "Error: wrong value for stop loss or take profit");
        return false;
    }
    return true;
}

// normalize price
bool Trade::NormalizePrice(double price, double &normalizedprice) {

   double tickSize = 0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tickSize)) {
      Print(PREFIX, "Failed to get tick size");
      return false;
   }
   normalizedprice = NormalizeDouble(MathRound(price/tickSize) * tickSize, _Digits);
   
   return true;
}


/**
 * set magic number to trade object
 * 
 * @param magic_number [ulong]
 * @returns (void)
 */
void Trade::SetMagicNumber(ulong magic_number) 
{
    trade.SetExpertMagicNumber(magic_number);
}

/**
 * Open position function
 * 
 * @param order_type [ENUM_ORDER_TYPE]  eg ORDER_TYPE_SELL/ORDER_TYPE_BUY
 * @param volume [double]   lots
 * @param price [double]    entry price
 * @param stop_points [double] points to compute for stop_loss price
 * @param profit_points [double] points tp compute for take_profit price
 * @param comments [string] comments
 * @returns (bool)
 */
bool Trade::OpenPosition(ENUM_ORDER_TYPE order_type, double volume, double price, double stop_points = 0, double profit_points = 0, string comment = NULL)
{
    //assign local variables
    double stop_loss = 0;
    double take_profit = 0;

    // compute prices
    bool order_computed = ComputePrice(order_type, price, stop_points, profit_points, stop_loss, take_profit);
    if(!order_computed) 
    {
        Print(PREFIX, "Error: Error computing prices");
        return false;
    }

    // normalize price
    NormalizePrice(price, price);
    // open position
    bool open_position = trade.PositionOpen(_Symbol, order_type, volume, price, stop_loss, take_profit, comment);
    if (!open_position) 
    {
        Print(PREFIX, "Error: Error opening position");
        return false;
    }
    return true;
}

/**
 * close open positions function
 * 
 * @param magic_number [ulong]
 * @returns (bool)
 */
bool Trade::ClosePositions(ulong magic_number) 
{
    int total_positions = PositionsTotal();

    for (int i = total_positions - 1; i >= 0; i--) 
    {
        if(total_positions != PositionsTotal()) {
            total_positions = PositionsTotal();
            continue;
        }

        ulong ticket = 0;
        long magic;
        if(!this.CheckOrder(magic, ticket, i, INSTANT)) return false;

        // check magic numbers to make sure the position belong to the current trade
        if(magic == magic_number) {
            trade.PositionClose(ticket);
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print(PREFIX, "Error: Failed to close position. ticket: ", (string)ticket, " result: ", (string)trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
                return false;
            }
        }
    }
    return true;
}

/**
 * count open positions function
 * 
 * @param magic_number [ulong]
 * @returns (int)
 */
int Trade::CountOpenPositions(ulong magic_number) 
{
    int counter = 0;
    int total_positions = PositionsTotal();

    for (int i = total_positions - 1; i >= 0; i--) 
    {
        ulong ticket = 0;
        long magic;
        if(!this.CheckOrder(magic, ticket, i, INSTANT)) return false;

        if(magic == magic_number) {
            counter++;
        }
   }
   return counter;
}

/**
 * Place pending order function
 * 
 * @param order_type [ENUM_ORDER_TYPE]  eg ORDER_TYPE_SELL/ORDER_TYPE_BUY
 * @param volume [double]   lots
 * @param price [double]    entry price
 * @param stop_points [double] points to compute for stop_loss price
 * @param profit_points [double] points tp compute for take_profit price
 * @param comments [string] comments
 * @returns (bool)
 */
bool Trade::OpenPendingOrder(ENUM_ORDER_TYPE order_type, double volume, double price, double stop_points = 0, double profit_points = 0, string comment = NULL) 
{
    //assign local variables
    double stop_loss = 0;
    double take_profit = 0;
    bool   order_placed = false;

    // compute prices
    bool order_computed = ComputePrice(order_type, price, stop_points, profit_points, stop_loss, take_profit);
    if(!order_computed) 
    {
        Print(PREFIX, "Error: Error computing prices");
        return false;
    }

    // order time type
    ENUM_ORDER_TYPE_TIME time_type = ORDER_TIME_SPECIFIED | ORDER_TIME_GTC;
    // pending orders expires in 2 hours if not triggered
    datetime expiration_time = TimeCurrent() + 3600 * 2;
    // normalize price
    NormalizePrice(price, price);

    // place order
    if (order_type == ORDER_TYPE_BUY_STOP)
    {
        order_placed = trade.BuyStop(volume, price, _Symbol, stop_loss, take_profit, time_type, expiration_time, comment);
    }

    if (order_type == ORDER_TYPE_BUY_LIMIT)
    {
        order_placed = trade.BuyLimit(volume, price, _Symbol, stop_loss, take_profit, time_type, expiration_time, comment);
    }

    if (order_type == ORDER_TYPE_SELL_STOP)
    {
        order_placed = trade.SellStop(volume, price, _Symbol, stop_loss, take_profit, time_type, expiration_time, comment);
    }

    if (order_type == ORDER_TYPE_SELL_LIMIT)
    {
        order_placed = trade.SellLimit(volume, price, _Symbol, stop_loss, take_profit, time_type, expiration_time, comment);
    }

    if (!order_placed) 
    {
        Print(PREFIX, "Error: Error placing an order");
        return false;
    }

    return true;
}

/**
 * Delete pending order function
 * 
 * @param magic_number [ulong]
 * @returns (bool)
 */
bool Trade::DeletePendingOrders(ulong magic_number) 
{
    int total_orders = OrdersTotal();

    for (int i = total_orders - 1; i >= 0; i--) 
    {
        if(total_orders != OrdersTotal()) {
            total_orders = OrdersTotal();
            continue;
        }

        ulong ticket = 0;
        long magic;
        int order_type = 0; 
        if(!this.CheckOrder(magic, ticket, i, PENDING)) return false;

        // check magic numbers to make sure the position belong to the current trade
        if(magic == magic_number) {
            trade.OrderDelete(ticket);
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print(PREFIX, "Error: Failed to delete order. ticket: ", (string)ticket, " result: ", (string)trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
                return false;
            }
        }
    }
    return true;
}

/**
 * count pending order function
 * 
 * @param magic_number [ulong]
 * @returns (int)
 */
int Trade::CountPendingOrders(ulong magic_number)
{
    int counter = 0;
    int total_orders = OrdersTotal();

    for (int i = total_orders - 1; i >= 0; i--) 
    {
        ulong ticket = 0;
        long magic;
        if(!this.CheckOrder(magic, ticket, i, PENDING)) return false;

        if(magic == magic_number) {
            counter++;
        }
    }
    return counter;
}


/**
 * update stop loss
 * 
 * @param magic_number [ulong]
 * @param did_price    [double]
 * @param ask_price    [double]
 * @returns (void)
 */
void Trade::UpdateStopLoss (ulong magic_number, double bid_price, double ask_price) 
{

       int total_positions = PositionsTotal();

    for (int i = total_positions - 1; i >= 0; i--) 
    {
        ulong ticket = 0;
        long magic;
        if(!this.CheckOrder(magic, ticket, i, INSTANT)) return;

        if(magic == magic_number) 
        {
            long type;
            if(!PositionGetInteger(POSITION_TYPE, type)) 
            {
                Print(PREFIX, "Failed to get position type");
                return;
            }
            double currSL, currTP;
            if(!PositionGetDouble(POSITION_SL, currSL)) 
            {
                Print(PREFIX, "Failed to get position stop loss");
                return;
            }
            if(!PositionGetDouble(POSITION_TP, currTP)) 
            {
                Print(PREFIX, "Failed to get position take profit");
                return;
            }

            // calculate stop loss
            double currentPrice = type == POSITION_TYPE_BUY ? bid_price : ask_price; 
            int n               = type == POSITION_TYPE_BUY ? 1 : -1;
            double newSL        = NormalizeDouble(currentPrice - (100 * 0.01 * n), _Digits);   

            // check if new stop loss is closer to current price than existing stop loss
            if((newSL * n) < (currSL * n) || NormalizeDouble(MathAbs(newSL-currSL), _Digits) < _Point) 
            {
                // Print(PREFIX, "No new stop loss needed");
                continue;
            } 

            // check for stop level
            long level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            if(level != 0 && MathAbs(currentPrice-newSL) <= level * _Point) 
            {
                Print(PREFIX, "New stop loss inside stop level");
            }

            // modify position with new stop loss
            if(!trade.PositionModify(ticket, newSL, currTP)) 
            {
                Print(PREFIX, "Failed to modify position, ticket: ", (string) ticket, " currSL: ", (string) currSL, 
                   " newSL: ", (string) newSL, " currTP: ", (string) currTP);
                return;   
            }
        }
   }


}