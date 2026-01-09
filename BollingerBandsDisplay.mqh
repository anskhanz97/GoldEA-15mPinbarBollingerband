//+------------------------------------------------------------------+
//|                  BollingerBandsDisplay.mqh                        |
//|              Bollinger Bands Detection Support Only               |
//+------------------------------------------------------------------+
// NOTE: Bollinger Bands are used for PATTERN DETECTION only.
// For visual display on chart, user should manually attach a standard
// Bollinger Bands indicator (period=50, deviation=2.0) to the chart.
// This module only provides helpers for BB value retrieval.

// Indicator handle for BB detection (15m only)
int g_bbM15Handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialize Bollinger Bands Indicators (for detection only)       |
//+------------------------------------------------------------------+
void InitBollingerBands() {
    // Create 15m BB indicator for detection
    g_bbM15Handle = iBands(_Symbol, PERIOD_M15, BB_PERIOD, 0, BB_DEVIATION, PRICE_CLOSE);
    if(g_bbM15Handle == INVALID_HANDLE) {
        Print("❌ Failed to create 15m Bollinger Bands for detection");
    } else {
        Print("✅ 15m Bollinger Bands initialized for detection");
    }
}

//+------------------------------------------------------------------+
//| Get Bollinger Band Values for Bar                                |
//+------------------------------------------------------------------+
bool GetBBValues(int handle, int barIndex, double &upper, double &middle, double &lower) {
    if(handle == INVALID_HANDLE) return false;
    
    double upperArr[], middleArr[], lowerArr[];
    ArraySetAsSeries(upperArr, true);
    ArraySetAsSeries(middleArr, true);
    ArraySetAsSeries(lowerArr, true);
    
    if(CopyBuffer(handle, 1, barIndex, 1, upperArr) <= 0) return false;
    if(CopyBuffer(handle, 0, barIndex, 1, middleArr) <= 0) return false;
    if(CopyBuffer(handle, 2, barIndex, 1, lowerArr) <= 0) return false;
    
    upper = upperArr[0];
    middle = middleArr[0];
    lower = lowerArr[0];
    
    return true;
}

//+------------------------------------------------------------------+
