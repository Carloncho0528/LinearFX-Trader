//+------------------------------------------------------------------+
//|                                                    LinearFX Trader |
//|                             Copyright 2025, Sisdigem |
//|                                 mailto:sedsist@gmail.com |
//+------------------------------------------------------------------+
#property copyright "2025"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Input parameters
input int    InpLookbackPeriod = 50;      // Lookback period for linear regression
input double InpLotSize        = 0.1;     // Lot size
input int    InpStopLoss       = 200;     // Stop loss in points
input int    InpTakeProfit     = 400;     // Take profit in points
input int    InpMagicNumber    = 123456;  // Magic number for trades
input int    InpSlippage       = 3;       // Maximum allowed slippage in points

// Global variables
double prices[];                          // Array for historical prices
CTrade *trade;                            // Trading object pointer
CPositionInfo *position;                  // Position information object pointer
bool isNewBar;                           // New bar flag

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize trade and position objects
    trade = new CTrade();
    position = new CPositionInfo();
    
    // Initialize price array
    ArrayResize(prices, InpLookbackPeriod);
    
    // Set up trading parameters
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(InpSlippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetMarginMode();
    
    // Validate inputs
    if(!ValidateInputs())
    {
        return INIT_PARAMETERS_INCORRECT;
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up resources
    ArrayFree(prices);
    delete trade;
    delete position;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar
    if(!IsNewBar())
        return;
        
    // Update price array
    if(!UpdatePrices())
        return;
        
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return;
        
    // Calculate linear regression
    double slope, intercept;
    if(!LinearRegression(prices, slope, intercept))
        return;
        
    // Predict future price
    double predictedPrice = intercept + slope * InpLookbackPeriod;
    
    // Get current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Trading logic
    if(predictedPrice > currentPrice)
    {
        OpenTrade(ORDER_TYPE_BUY);
    }
    else if(predictedPrice < currentPrice)
    {
        OpenTrade(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Calculate linear regression                                        |
//+------------------------------------------------------------------+
bool LinearRegression(const double &data[], double &slope, double &intercept)
{
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    int n = ArraySize(data);
    
    if(n < 2)
        return false;
        
    for(int i = 0; i < n; i++)
    {
        sumX += i;
        sumY += data[i];
        sumXY += i * data[i];
        sumX2 += i * i;
    }
    
    double denominator = (n * sumX2 - sumX * sumX);
    if(denominator == 0)
        return false;
        
    slope = (n * sumXY - sumX * sumY) / denominator;
    intercept = (sumY - slope * sumX) / n;
    
    return true;
}

//+------------------------------------------------------------------+
//| Open a trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type)
{
    double price, sl, tp;
    
    if(type == ORDER_TYPE_BUY)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = price - InpStopLoss * _Point;
        tp = price + InpTakeProfit * _Point;
        trade.Buy(InpLotSize, _Symbol, price, sl, tp, "LinearFX Buy");
    }
    else if(type == ORDER_TYPE_SELL)
    {
        price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = price + InpStopLoss * _Point;
        tp = price - InpTakeProfit * _Point;
        trade.Sell(InpLotSize, _Symbol, price, sl, tp, "LinearFX Sell");
    }
}

//+------------------------------------------------------------------+
//| Update price array with new data                                   |
//+------------------------------------------------------------------+
bool UpdatePrices()
{
    for(int i = 0; i < InpLookbackPeriod; i++)
    {
        prices[i] = iClose(_Symbol, PERIOD_CURRENT, i);
        if(prices[i] == 0)
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check if we have a new bar                                         |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if(lastBar != currentBar)
    {
        lastBar = currentBar;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Validate input parameters                                          |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(InpLookbackPeriod <= 0)
    {
        Print("Lookback period must be positive");
        return false;
    }
    
    if(InpLotSize <= 0 || InpLotSize > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX))
    {
        Print("Invalid lot size");
        return false;
    }
    
    if(InpStopLoss <= 0 || InpTakeProfit <= 0)
    {
        Print("Stop loss and take profit must be positive");
        return false;
    }
    
    return true;
}