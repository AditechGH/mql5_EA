#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <myIncludes\NDS\Definitions.mqh>

//+------------------------------------------------------------------+
//|  Class CMoneyManagment                                           |
//+------------------------------------------------------------------+

class CMoneyManagment
  {
    private:
        double      initial_balance;
        bool        InitialBalance(void);
        bool        CheckVolume(double &volume, ENUM_ORDER_TYPE order_type, double price);

    public:
        void        CMoneyManagment();
        void        ~CMoneyManagment();
        bool        MoneyManagement(double max_loss, double max_profit);
        bool        VolumeManagement(double slDistance, double &volume, ENUM_LOT_MODE mode, ENUM_ORDER_TYPE order_type, double price);
        double      StopPoints(double stop_price, double entry_price);
  };

  // constructor
void CMoneyManagment::CMoneyManagment(void) {};

// deconstructor
void CMoneyManagment::~CMoneyManagment(void) {};


// Retrive starting account balance
bool CMoneyManagment::InitialBalance(void)
{
    // retrive the history of deals and orders
    bool deals = HistorySelect(0,TimeCurrent());
    if(!deals) 
    {
        Print(PREFIX, "Error: Retriving the deals was unsuccessful");
        return false;
    }

    // select the initial deal ticket in history
    ulong ticket =  HistoryDealGetTicket(0);
    if(ticket < 1) 
    {
        Print(PREFIX, "Error: Retriving the initial deal ticket was unsuccessful");
        return false;
    }

    // retrive the initial amount
    initial_balance = HistoryDealGetDouble(ticket, DEAL_PROFIT);
    return true;
};

// check and set lot size
bool CMoneyManagment::CheckVolume(double &volume, ENUM_ORDER_TYPE order_type, double price) 
{
    double margin = 0.0;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);

    double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max = (balance * leverage) / contract_size;
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // set lot size
    if ( volume < min ) volume = min;
    if ( volume > max ) volume = max;
    
    if(!OrderCalcMargin(order_type, _Symbol, volume, price, margin))
    {
        Print(PREFIX, "Error: Margin Calculation Error");
        volume = min;
    }
    
    if(free_margin - margin <= 0.0) 
    {
       double m_volume = (margin * leverage) / contract_size;
       volume = volume - (m_volume - volume);
    }
     
    volume = NormalizeDouble(volume, 2);

    return true;
}


/**
 * Check if max equity profit/drawdown has reached function
 * 
 * @param max_profit   [double]
 * @param max_drawdown [double]
 * @returns            (bool)
 */
bool CMoneyManagment::MoneyManagement(double max_profit, double max_drawdown) 
{
    if (max_drawdown > MAX_EQUITY_DRAWDWON) max_drawdown = MAX_EQUITY_DRAWDWON;
    if (max_profit > MAX_EQUITY_PROFIT) max_profit = MAX_EQUITY_PROFIT;

    // intial balance
    double balance = InitialBalance();
    if(!balance) return false;

    // account equity
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    // get the account difference
    double diff = equity - balance;

    // calculate the percentage profit/loss on the account
    double percentile = (fabs(diff) * 100) / balance;

    // check if max loss/profilt is reached
    return ( (diff > 0 && percentile >= max_profit) || (diff < 0 && percentile >= max_drawdown));
};

/**
 * Lot size management function
 * 
 * @param slDistance [double]
 * @param volume     [double]
 * @param mode       [ENUM_LOT_MODE]
 * @param order_type [ENUM_ORDER_TYPE]
 * @param price      [double]
 * @returns          (bool)
 */
bool CMoneyManagment::VolumeManagement(double slDistance, double &volume, ENUM_LOT_MODE mode, ENUM_ORDER_TYPE order_type, double price) 
{
    if(mode != LOT_MODE_FIXED)
    {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);

        double risk_money = (mode == LOT_MODE_MONEY) ? volume : equity * (volume / 100);
        double risk_per_pip = risk_money / (slDistance / 10);

        double pip_value = 10 * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

        volume = risk_per_pip / pip_value;  
    }

    // check calculated volume
    if (!CheckVolume(volume, order_type, price)) return false;

    volume = NormalizeDouble(volume, 2);

    return true;
};

/**
 *  Calculate stop loss distance in points
 * 
 * @param stop_price  [double]
 * @param entry_price [double]
 * @returns          (double)
 */
double CMoneyManagment::StopPoints(double stop_price, double entry_price)
{
    long   spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread > MAX_SPREAD) spread = MAX_SPREAD;
    
	double stopDiff = MathAbs(stop_price - entry_price);
	double priceToPoint = stopDiff / _Point;
    double slDistance = priceToPoint + spread + 10;

    if(slDistance < MIN_DISTANCE) slDistance = MIN_DISTANCE;
    if(slDistance > MAX_DISTANCE) slDistance = MAX_DISTANCE;
	return slDistance;
}
