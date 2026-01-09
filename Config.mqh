//+------------------------------------------------------------------+
//|                          Config.mqh                               |
//|              Pinbar + Bollinger Bands Scalper v2.0                |
//|                  Clean Configuration File                         |
//+------------------------------------------------------------------+

//=== PINBAR DETECTION SETTINGS ===
input group "=== PINBAR DETECTION ==="
input double InpWickRatioMin = 0.2;              // Minimum Wick-to-Body Ratio
input double InpMinWickPips = 100.0;             // Absolute minimum wick size (pips)
input double InpBBTouchTolerance = 300.0;        // Band Touch Tolerance (pips)
input bool InpStrictBandCheck = true;            // No Band Through Body
input bool InpBBToleranceRelative = true;        // Use relative band width %
input double InpBBTolerancePct = 50.0;           // Percent of (Upper-Lower)
input double InpBBToleranceAtrMult = 0.5;        // ATR-based component (fraction of ATR)
input int InpBBToleranceAtrPeriod = 14;          // ATR period for tolerance blending
input double InpBBTouchBufferPct = 0.20;         // Extra % of tolerance allowed for wick tip (grace buffer)
input bool InpLenientMode = true;                // Lenient detection mode
input bool InpCheckBothWicks = true;            // Check BOTH wicks independently (not just directional)
input bool InpDrawAllTimeframes = true;          // Draw lines on all charts regardless of chart TF
input bool InpLogScanTable = false;              // Verbose table log for each scanned bar
input bool InpLiveDetectionLog = false;          // Log each new 15m candle detection attempt
input bool InpDrawRejectedCandles = false;       // Draw circles on rejected candles (for debugging)
input color InpRejectedColor = clrOrange;        // Color for rejected candle markers

//=== HISTORICAL SCAN CONTROLS ===
input group "=== HISTORICAL SCAN ==="
input bool InpUseScanStart = false;              // If true, scan from specific start date/time
input datetime InpScanStartTime = 0;             // Start date/time for focused scan (e.g., 2025.12.16 12:45). 0 = disabled
input bool InpWriteScanCsv = false;              // Write detailed historical scan results to CSV

//=== ENTRY & EXIT SETTINGS ===
input group "=== ENTRY & EXIT LOGIC ==="
input double InpSLOffsetPips = 10.0;             // SL Offset from Wick (pips)
input bool InpEnableMaxSLLimit = true;           // Enable Maximum SL Cap
input double InpMaxSLPips = 40.0;                // Maximum Allowed SL (pips)
input double InpTPPips = 50.0;                   // Take Profit Distance (pips)

//=== BREAK-EVEN SETTINGS ===
input group "=== BREAK-EVEN MODE ==="
input bool InpEnableBreakEven = true;            // Enable Break-Even
input double InpBEStartPips = 40.0;              // Profit Needed for BE (pips)
input double InpBEOffsetPips = 0.0;              // BE Offset (pips) [0=exact entry]

//=== TRAILING STOP SETTINGS ===
input group "=== TRAILING STOP LOSS ==="
input bool InpEnableTrailingSL = false;          // Enable Trailing SL
input double InpTrailDistancePips = 20.0;        // Trail Distance (pips)

//=== POSITION SIZING ===
input group "=== POSITION SIZING ==="
input double InpLotSize = 0.01;                  // Lot Size per Trade

//=== HISTORICAL TRACKING ===
input group "=== TRACKING & ALERTS ==="
input int InpHistoryDays = 14;                   // Track Past X Days
input bool InpDebugMode = false;                 // Debug Mode
input bool InpEnableAlerts = true;               // Enable Pop Alerts

//=== BOLLINGER BANDS SETTINGS (FIXED) ===
#define BB_PERIOD 50
#define BB_DEVIATION 2.0

//=== TIMEFRAME SETTINGS (FIXED) ===
#define PRIMARY_TF PERIOD_M15

//=== SETUP STATES ===
#define SETUP_PENDING    0
#define SETUP_EXECUTED   1
#define SETUP_CLOSED     2

//=== TRADE RESULTS ===
#define RESULT_PENDING   0
#define RESULT_TP_HIT    1
#define RESULT_SL_HIT    2
#define RESULT_MANUAL    3

//=== BAND INTERACTION TYPES ===
#define BAND_NONE        0
#define BAND_LOWER       1
#define BAND_MIDDLE      2
#define BAND_UPPER       3

//+------------------------------------------------------------------+
//| Pinbar Setup Structure (SIMPLIFIED)                              |
//+------------------------------------------------------------------+
struct PinbarSetup {
    // ===== IDENTITY =====
    string setupID;                // "PinbarBB-2026.01.06-16:45-H1"
    datetime formationTime;        // Candle close time
    int timeframe;                 // PERIOD_M15 only for this EA
    
    // ===== PINBAR METRICS =====
    bool isBullish;                // True = LONG, False = SHORT
    double wickLow;                // Low of candle
    double wickHigh;               // High of candle
    double candleOpen;
    double candleClose;
    double wickSize;               // In pips
    double bodySize;               // In pips
    double ratio;                  // wick/body ratio
    
    // ===== BB INTERACTION =====
    int touchedBand;               // BAND_LOWER, BAND_MIDDLE, BAND_UPPER
    double bandPrice;              // The BB value touched
    double bbUpper;                // BB Upper at formation
    double bbMiddle;               // BB Middle at formation
    double bbLower;                // BB Lower at formation
    
    // ===== TRADE EXECUTION =====
    ulong orderTicket;             // Single market order ticket
    double entryPrice;             // Market order execution price
    double stopLoss;               // Calculated SL
    double takeProfit;             // Fixed TP
    datetime orderTime;            // When market order placed
    
    // ===== POSITION STATE =====
    int state;                     // PENDING, EXECUTED, CLOSED
    int result;                    // TP, SL, MANUAL, PENDING
    double profit;                 // In account currency
    datetime closeTime;            // When position closed
    
    // ===== TRAIL & BE FLAGS =====
    bool breakEvenTriggered;       // BE activated
    bool trailingActivated;        // Trailing SL active
    datetime lastTrailUpdate;      // Last SL modification
    
    // ===== VISUAL =====
    string lineName;               // Vertical line object name
    
    // ===== CONSTRUCTOR =====
    PinbarSetup() {
        setupID = "";
        formationTime = 0;
        timeframe = PERIOD_M15;
        isBullish = false;
        wickLow = 0;
        wickHigh = 0;
        candleOpen = 0;
        candleClose = 0;
        wickSize = 0;
        bodySize = 0;
        ratio = 0;
        touchedBand = BAND_NONE;
        bandPrice = 0;
        bbUpper = 0;
        bbMiddle = 0;
        bbLower = 0;
        orderTicket = 0;
        entryPrice = 0;
        stopLoss = 0;
        takeProfit = 0;
        orderTime = 0;
        state = SETUP_PENDING;
        result = RESULT_PENDING;
        profit = 0;
        closeTime = 0;
        breakEvenTriggered = false;
        trailingActivated = false;
        lastTrailUpdate = 0;
        lineName = "";
    }
};

//=== GLOBAL ARRAYS ===
PinbarSetup g_setups[];           // 15m setups (14 day history)

//=== GLOBAL TRACKING ===
int g_totalSetups = 0;
int g_totalTP = 0;
int g_totalSL = 0;
double g_totalProfit = 0;

//+------------------------------------------------------------------+
