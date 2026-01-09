//+------------------------------------------------------------------+
//|                 Gold15mPinbarBB_Main.mq5                          |
//|        Pinbar + Bollinger Bands Scalper - 15m Only                 |
//|                    v2.0 - CLEAN ARCHITECTURE                     |
//+------------------------------------------------------------------+

#property copyright "Trading Strategy"
#property version   "2.00"
#property strict
#property description "Pinbar + BB Scalper (15m only) - Market Orders Only"

#include "IncludePinBar/Config.mqh"
#include "IncludePinBar/PinbarDetector.mqh"
#include "IncludePinBar/TradeManager.mqh"
#include "IncludePinBar/TrailingSL.mqh"
#include "IncludePinBar/VisualManager.mqh"
#include "IncludePinBar/BollingerBandsDisplay.mqh"


//=== GLOBAL TRACKING ===
datetime g_lastM15BarTime = 0;
int g_totalM15Setups = 0;
bool g_historicalScanDone = false;   // Flag to prevent repeated scans

// Near-miss tracking for diagnostics
#define NEAR_MISS_MAX 20
struct NearMissEntry {
    datetime time;
    int timeframe;
    bool isBull;
    double distPrimary;
    double tol;
    double bandPrice;
    double bbUpper;
    double bbMiddle;
    double bbLower;
    double wickPips;
    double bodyPips;
    double ratio;
    string reason;
};
NearMissEntry g_nearMissM15[];

//+------------------------------------------------------------------+
//| Print All Active Settings Table                                  |
//+------------------------------------------------------------------+
void PrintAllSettings() {
    Print("\n╔═══════════════════════════════════════════════════════════════════════════════╗");
    Print("║                     🔧 ACTIVE SETTINGS TABLE 🔧                              ║");
    Print("╠═══════════════════════════════════════════════════════════════════════════════╣");
    
    // Pinbar Detection Settings
    Print("║ ┌─ PINBAR DETECTION SETTINGS ─────────────────────────────────────────────────┐ ║");
    Print("║ │ Wick-to-Body Ratio Min               : ", DoubleToString(InpWickRatioMin, 2), StringRepeat(" ", 5), "│ ║");
    Print("║ │ Min Wick Size (pips)                 : ", DoubleToString(InpMinWickPips, 1), StringRepeat(" ", 10), "│ ║");
    Print("║ │ Strict Band Through Body Check       : ", (InpStrictBandCheck ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ Check Both Wicks (Counter-wicks)     : ", (InpCheckBothWicks ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ Lenient Mode                         : ", (InpLenientMode ? "YES (1.5x tolerance)" : "NO (strict)"), StringRepeat(" ", 40), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Bollinger Bands Settings
    Print("║ ┌─ BOLLINGER BANDS TOLERANCE SETTINGS ────────────────────────────────────────┐ ║");
    Print("║ │ Use Relative Tolerance               : ", (InpBBToleranceRelative ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    if(InpBBToleranceRelative) {
        Print("║ │ BB Tolerance (% of band width)       : ", DoubleToString(InpBBTolerancePct, 1), "%", StringRepeat(" ", 50), "│ ║");
        Print("║ │ BB Tolerance Floor (pips)           : ", DoubleToString(InpBBTouchTolerance, 1), " pips", StringRepeat(" ", 45), "│ ║");
    } else {
        Print("║ │ BB Tolerance (Fixed - pips)         : ", DoubleToString(InpBBTouchTolerance, 1), " pips", StringRepeat(" ", 45), "│ ║");
    }
    Print("║ │ ATR Period                           : ", InpBBToleranceAtrPeriod, StringRepeat(" ", 62), "│ ║");
    Print("║ │ ATR Multiplier                       : ", DoubleToString(InpBBToleranceAtrMult, 3), "x ATR", StringRepeat(" ", 45), "│ ║");
    Print("║ │ BB Touch Buffer (grace margin)       : ", DoubleToString(InpBBTouchBufferPct * 100.0, 1), "%", StringRepeat(" ", 50), "│ ║");
    Print("║ │ BB Period (FIXED)                    : 50", StringRepeat(" ", 57), "│ ║");
    Print("║ │ BB Deviation (FIXED)                 : 2.0", StringRepeat(" ", 55), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Entry & Exit Settings
    Print("║ ┌─ ENTRY & EXIT LOGIC SETTINGS ───────────────────────────────────────────────┐ ║");
    Print("║ │ Take Profit (Fixed - pips)          : ", DoubleToString(InpTPPips, 0), " pips", StringRepeat(" ", 50), "│ ║");
    Print("║ │ SL Offset from Wick (pips)           : ", DoubleToString(InpSLOffsetPips, 1), " pips", StringRepeat(" ", 49), "│ ║");
    Print("║ │ Enable Max SL Limit                  : ", (InpEnableMaxSLLimit ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ Max SL Cap (pips)                    : ", DoubleToString(InpMaxSLPips, 0), " pips", StringRepeat(" ", 50), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Break-Even Settings
    Print("║ ┌─ BREAK-EVEN MODE SETTINGS ──────────────────────────────────────────────────┐ ║");
    Print("║ │ Enable Break-Even                    : ", (InpEnableBreakEven ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ BE Profit Threshold (pips)           : ", DoubleToString(InpBEStartPips, 1), " pips", StringRepeat(" ", 45), "│ ║");
    Print("║ │ BE Offset (pips)                     : ", DoubleToString(InpBEOffsetPips, 1), " pips", StringRepeat(" ", 49), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Trailing Stop Settings
    Print("║ ┌─ TRAILING STOP LOSS SETTINGS ───────────────────────────────────────────────┐ ║");
    Print("║ │ Enable Trailing SL                   : ", (InpEnableTrailingSL ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ Trail Distance (pips)                : ", DoubleToString(InpTrailDistancePips, 1), " pips", StringRepeat(" ", 49), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Position Sizing
    Print("║ ┌─ POSITION SIZING & TRACKING ───────────────────────────────────────────────┐ ║");
    Print("║ │ Lot Size (per trade)                 : ", DoubleToString(InpLotSize, 2), StringRepeat(" ", 54), "│ ║");
    Print("║ │ History Days (to track)              : ", InpHistoryDays, " days", StringRepeat(" ", 48), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Logging & Debugging Settings
    Print("║ ┌─ LOGGING & DEBUGGING SETTINGS ──────────────────────────────────────────────┐ ║");
    Print("║ │ Debug Mode                           : ", (InpDebugMode ? "ON" : "OFF"), StringRepeat(" ", 54), "│ ║");
    Print("║ │ Enable Pop-Up Alerts                 : ", (InpEnableAlerts ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ Log Scan Table (verbose)             : ", (InpLogScanTable ? "ON" : "OFF"), StringRepeat(" ", 54), "│ ║");
    Print("║ │ Log Live Detection (verbose)         : ", (InpLiveDetectionLog ? "ON" : "OFF"), StringRepeat(" ", 54), "│ ║");
    Print("║ │ Draw Rejected Candles                : ", (InpDrawRejectedCandles ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ │ Draw All Timeframes                  : ", (InpDrawAllTimeframes ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // Historical Scan Settings
    Print("║ ┌─ HISTORICAL SCAN SETTINGS ──────────────────────────────────────────────────┐ ║");
    Print("║ │ Use Scan Start Date/Time             : ", (InpUseScanStart ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    if(InpUseScanStart && InpScanStartTime > 0) {
        Print("║ │ Scan Start: ", TimeToString(InpScanStartTime, TIME_DATE|TIME_MINUTES), StringRepeat(" ", 57), "│ ║");
    }
    Print("║ │ Write Scan Results to CSV            : ", (InpWriteScanCsv ? "YES" : "NO"), StringRepeat(" ", 52), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    // System Info
    Print("║ ┌─ SYSTEM INFORMATION ───────────────────────────────────────────────────────┐ ║");
    Print("║ │ Symbol                               : ", _Symbol, StringRepeat(" ", 55), "│ ║");
    Print("║ │ Timeframe                            : 15 Minutes", StringRepeat(" ", 46), "│ ║");
    Print("║ │ _Point Value                         : ", DoubleToString(_Point, 6), StringRepeat(" ", 48), "│ ║");
    Print("║ │ Account Currency                     : ", AccountCurrency(), StringRepeat(" ", 50), "│ ║");
    Print("║ └─────────────────────────────────────────────────────────────────────────────┘ ║");
    
    Print("╚═══════════════════════════════════════════════════════════════════════════════╝\n");
}

//+------------------------------------------------------------------+
//| Helper: Repeat a string n times                                  |
//+------------------------------------------------------------------+
string StringRepeat(string str, int times) {
    string result = "";
    for(int i = 0; i < times; i++) result += str;
    return result;
}

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit() {
    Print("\n╔════════════════════════════════════════════════════════════════╗");
    Print("║       PINBAR + BOLLINGER BANDS SCALPER - 15M ONLY            ║");
    Print("║                     v2.0 - FRESH START                        ║");
    Print("╠════════════════════════════════════════════════════════════════╣");
    Print("║ Symbol: ", _Symbol);
    Print("║ Timeframe: 15m");
    Print("║ Entry: Pinbar + BB Touch");
    Print("║ Exit: Fixed TP ", DoubleToString(InpTPPips, 0), "pips");
    Print("║ SL: Wick + ", DoubleToString(InpSLOffsetPips, 0), "pips (Max: ",
          InpEnableMaxSLLimit ? DoubleToString(InpMaxSLPips, 0) : "Unlimited", ")");
    Print("║ Trailing: ", (InpEnableTrailingSL ? "ON" : "OFF"));
    Print("║ Lot Size: ", DoubleToString(InpLotSize, 2));
    Print("║ Check Both Wicks: ", (InpCheckBothWicks ? "ON (Counter-wicks detected)" : "OFF (Directional only)"));
        Print("║ BB Tolerance: ", (InpBBToleranceRelative ? "RELATIVE " + DoubleToString(InpBBTolerancePct, 1) + "%" : "FIXED " + DoubleToString(InpBBTouchTolerance, 1) + "pips"),
            " + ATR mix ", DoubleToString(InpBBToleranceAtrMult, 3), "*ATR");
    Print("╠════════════════════════════════════════════════════════════════╣");
    Print("║ IMPORTANT: Manually add Bollinger Bands to chart for display! ║");
    Print("║ Settings: Period=50, Deviation=2.0, Applied to Close price   ║");
    Print("║ The EA uses BB internally for pattern detection.              ║");
    Print("║ Historical scan will run after BB indicator is ready (5-10s)  ║");
    Print("╚════════════════════════════════════════════════════════════════╝\n");
    
    // Print comprehensive settings table
    PrintAllSettings();
    
    // User-friendly echo of BB tolerance scale
    double tolPriceInit = InpBBToleranceRelative ? -1.0 : InpBBTouchTolerance * _Point;
    if(InpBBToleranceRelative) {
          Print("ℹ️ BB Touch Tolerance: ", DoubleToString(InpBBTolerancePct, 2), "% of band width, floor ",
              DoubleToString(InpBBTouchTolerance, 1), " pips, ATR mix ", DoubleToString(InpBBToleranceAtrMult, 3),
              "*ATR", " (_Point=", DoubleToString(_Point, 6), ")");
    } else {
        Print("ℹ️ BB Touch Tolerance: ", DoubleToString(InpBBTouchTolerance, 1), " pips (",
              DoubleToString(tolPriceInit, 3), " price units). _Point=", DoubleToString(_Point, 6));
    }
    if(!InpBBToleranceRelative && tolPriceInit < 0.01) {
      Print("⚠️ BB tolerance may be too tight for ", _Symbol, 
          ". Consider 50–150 pips for XAUUSD-like symbols.");
    }
    
    // Initialize arrays
    ArrayResize(g_setups, 0);
    
    // Initialize Bollinger Bands detection
    InitBollingerBands();
    
    // DO NOT scan historical data yet - wait for BB to warm up
    // This will be done on first few OnTick() calls
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("\n🛑 EA STOPPING - Reason: ", GetStopReason(reason));
    Print("🧹 Cleaning up all chart objects (lines & markers)...");
    
    // Robust cleanup via visual manager helper
    DeleteAllPinbarLines();
    
    // Fallback: remove any leftover objects with our prefixes
    int deleted = 0;
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "PinbarBB-") == 0 || 
           StringFind(objName, "Pinbar_") == 0 || 
           StringFind(objName, "Rejected_") == 0) {
            if(ObjectDelete(0, objName)) deleted++;
        }
    }
    
    Print(StringFormat("✅ Deleted %d residual chart objects", deleted));
    Print("═══════════════════════════════════════════════════════\n");
}

//+------------------------------------------------------------------+
//| Check if Bollinger Bands Indicator is Ready                      |
//+------------------------------------------------------------------+
bool IsBollingerBandsReady() {
    int bbHandle15m = iBands(_Symbol, PERIOD_M15, BB_PERIOD, 0, BB_DEVIATION, PRICE_CLOSE);
    if(bbHandle15m == INVALID_HANDLE) return false;
    
    double testUpper[], testMiddle[], testLower[];
    ArraySetAsSeries(testUpper, true);
    ArraySetAsSeries(testMiddle, true);
    ArraySetAsSeries(testLower, true);
    
    if(CopyBuffer(bbHandle15m, 1, 0, 10, testUpper) < 10) return false;
    if(CopyBuffer(bbHandle15m, 0, 0, 10, testMiddle) < 10) return false;
    if(CopyBuffer(bbHandle15m, 2, 0, 10, testLower) < 10) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    
    // ===== DYNAMIC HISTORICAL SCAN (wait until BB is actually ready) =====
    if(!g_historicalScanDone) {
        if(IsBollingerBandsReady()) {
            Print("✅ Bollinger Bands ready - loading historical setups...");
            LoadHistoricalSetups();
            RedrawHistoricalLines();
            g_historicalScanDone = true;
            Print("✅ Historical scan complete. EA now trading...");
        }
        return;
    }
    
    // ===== CHECK 15M TIMEFRAME =====
    datetime m15BarTime = iTime(_Symbol, PERIOD_M15, 0);
    if(m15BarTime != g_lastM15BarTime) {
        g_lastM15BarTime = m15BarTime;
        
        PinbarSetup m15Setup = DetectPinbar(PERIOD_M15);
        if(InpLiveDetectionLog) {
            LogLiveDetection(PERIOD_M15, 0, m15Setup);
        }
        if(m15Setup.setupID != "") {
            ArrayResize(g_setups, ArraySize(g_setups) + 1);
            g_setups[ArraySize(g_setups) - 1] = m15Setup;
            g_totalM15Setups++;
            
            DrawPinbarLine(m15Setup);
            PlaceMarketTrade(m15Setup);
        }
    }
    
    // ===== TRAIL EXISTING POSITIONS =====
    if(InpEnableTrailingSL) {
        TrailAllPositions();
    }
    
    // ===== MONITOR POSITION RESULTS =====
    MonitorPositions();
}

//+------------------------------------------------------------------+
//| Monitor Open Positions for Results                               |
//+------------------------------------------------------------------+
void MonitorPositions() {
    
    // Check 15m positions
    for(int i = 0; i < ArraySize(g_setups); i++) {
        if(g_setups[i].orderTicket <= 0) continue;
        if(g_setups[i].state == SETUP_CLOSED) continue;
        
        ulong ticket = g_setups[i].orderTicket;
        
        if(!PositionSelectByTicket(ticket)) {
            // Position closed
            g_setups[i].state = SETUP_CLOSED;
            g_setups[i].closeTime = TimeCurrent();
            
            double profit = PositionGetDouble(POSITION_PROFIT);
            g_setups[i].profit = profit;
            
            if(profit > 0) {
                g_setups[i].result = RESULT_TP_HIT;
                g_totalTP++;
                Print("✅ 15m SETUP TP HIT: ", g_setups[i].setupID, " | Profit: $", profit);
            } else {
                g_setups[i].result = RESULT_SL_HIT;
                g_totalSL++;
                Print("❌ 15m SETUP SL HIT: ", g_setups[i].setupID, " | Loss: $", profit);
            }
            
            g_totalProfit += profit;
            continue;
        }
        
        // Position still open - check for TP
        if(IsPositionTPHit(ticket)) {
            g_setups[i].result = RESULT_TP_HIT;
            g_setups[i].profit = PositionGetDouble(POSITION_PROFIT);
            ClosePosition(ticket, "TP HIT");
            g_totalTP++;
        }
    }
}

//+------------------------------------------------------------------+
//| Load Historical Setups (Recent 100 15m Candles)                  |
//+------------------------------------------------------------------+
void LoadHistoricalSetups() {
    Print("\n╔════════════════════════════════════════════════════════════════╗");
    Print("║  🔍 PINBAR DETECTION SCAN - LAST 100 15M CANDLES               ║");
    Print("╠════════════════════════════════════════════════════════════════╣");
    
    // Log all parameters for this scan
    Print("║ Wick Ratio Min: ", DoubleToString(InpWickRatioMin, 2), " | ATR Period: ", InpBBToleranceAtrPeriod);
    Print("║ BB Tolerance: ", (InpBBToleranceRelative ? "RELATIVE " + DoubleToString(InpBBTolerancePct, 2) + "%" : "FIXED " + DoubleToString(InpBBTouchTolerance, 1) + "pips"),
          " + ATR*", DoubleToString(InpBBToleranceAtrMult, 3));
    Print("║ Strict Band Check: ", (InpStrictBandCheck ? "ON" : "OFF"), " | Buffer: ", DoubleToString(InpBBTouchBufferPct * 100, 1), "%");
    Print("╚════════════════════════════════════════════════════════════════╝\n");
    
    double pipValue = _Point;
    
    // ===== SCAN RANGE: by start date or by days =====
    int barsAvailable = Bars(_Symbol, PERIOD_M15);
    int bars15mToScan = 0;
    int startIndex = -1;
    
    if(InpUseScanStart && InpScanStartTime > 0) {
        startIndex = iBarShift(_Symbol, PERIOD_M15, InpScanStartTime, true);
        if(startIndex > 1) {
            bars15mToScan = startIndex; // scan from startIndex down to 2
            Print("📊 Historical scanner: since ", TimeToString(InpScanStartTime, TIME_DATE|TIME_MINUTES), 
                  " (", bars15mToScan, " candles)...\n");
        }
    }
    if(bars15mToScan <= 0) {
        int barsNeeded = InpHistoryDays * 96; // 96 bars per day on 15m
        bars15mToScan = MathMin(barsNeeded, barsAvailable - 1); // skip current forming bar
        if(bars15mToScan <= 0) bars15mToScan = 100; // safety fallback
        Print("📊 Historical scanner: last ", InpHistoryDays, " days (", bars15mToScan, " candles)...\n");
    }
    
    int m15BBMatches = 0;
    ArrayResize(g_nearMissM15, 0);
    
    // Optional CSV logging
    int csv = INVALID_HANDLE;
    if(InpWriteScanCsv) {
        csv = FileOpen("ScanLog.csv", FILE_WRITE|FILE_CSV|FILE_ANSI);
        if(csv != INVALID_HANDLE) {
            FileWrite(csv, "time", "dir", "open", "high", "low", "close", 
                      "body_pips", "wick_pips", "ratio", 
                      "bb_upper", "bb_middle", "bb_lower", 
                      "tol_pips", "result", "reason", "setup_id", "band", "dist_to_band_pips");
        } else {
            Print("⚠️ Failed to open ScanLog.csv for writing");
        }
    }

    for(int i = bars15mToScan; i >= 2; i--) {
        double open = iOpen(_Symbol, PERIOD_M15, i);
        double high = iHigh(_Symbol, PERIOD_M15, i);
        double low = iLow(_Symbol, PERIOD_M15, i);
        double close = iClose(_Symbol, PERIOD_M15, i);
        datetime time = iTime(_Symbol, PERIOD_M15, i);
        
        if(open == 0) continue;
        
        // Calculate body and wick metrics
        double bodySize = MathAbs(close - open);
        double bodyHigh = MathMax(open, close);
        double bodyLow = MathMin(open, close);
        double lowerWick = bodyLow - low;
        double upperWick = high - bodyHigh;
        double wickSize = (close > open) ? lowerWick : upperWick;
        
        double bodySizePips = bodySize / pipValue;
        double wickSizePips = wickSize / pipValue;
        double ratio = (bodySizePips > 0) ? (wickSizePips / bodySizePips) : 0;
        
        // Get BB values
        double bbUpper=0, bbMiddle=0, bbLower=0;
        bool hasBB = GetBBValues(g_bbM15Handle, i, bbUpper, bbMiddle, bbLower);
        
        double atr = hasBB ? GetATR(PERIOD_M15, InpBBToleranceAtrPeriod, i + 1) : 0;
        double tolPrice = hasBB ? ComputeTolerancePrice(bbUpper, bbLower, pipValue, atr) : 0;
        double tolEff = tolPrice * (1.0 + InpBBTouchBufferPct);
        double tolEffPips = (pipValue > 0) ? tolEff / pipValue : 0;
        
        string dirStr = (close > open) ? "🟢 BULL" : (close < open ? "🔴 BEAR" : "⚪ DOJI");
        string timeStr = TimeToString(time, TIME_DATE|TIME_MINUTES);
        
        // Print every candle with full details
        Print(StringFormat("[%s] %s | OHLC: O=%.2f H=%.2f L=%.2f C=%.2f | Body=%.1fp Wick=%.1fp Ratio=%.2f",
                           timeStr, dirStr, open, high, low, close, bodySizePips, wickSizePips, ratio));
        Print(StringFormat("         BB: Upper=%.2f | Mid=%.2f | Lower=%.2f | ATR=%.2f | TolEff=%.1fp",
                           bbUpper, bbMiddle, bbLower, atr, tolEffPips));
        
        // Try full detection
        PinbarSetup setup = DetectPinbar(PERIOD_M15, i);
        if(setup.setupID != "") {
            // ✅ PASSED - VALIDATED PATTERN DETECTED
            ArrayResize(g_setups, ArraySize(g_setups) + 1);
            g_setups[ArraySize(g_setups) - 1] = setup;
            DrawPinbarLine(setup);  // DRAW LINE for detected pattern
            m15BBMatches++;
            
            double distToBand = setup.isBullish ? MathAbs(low - setup.bandPrice) : MathAbs(high - setup.bandPrice);
            string bandStr = (setup.touchedBand == BAND_LOWER) ? "LOWER" : (setup.touchedBand == BAND_UPPER ? "UPPER" : "MIDDLE");
            string signalType = setup.isBullish ? "🟢 LONG SIGNAL" : "🔴 SHORT SIGNAL";
            
            // Detailed pass logging
            Print("         ═══════════════════════════════════════════════════════");
            Print(StringFormat("         ✅ %s - PATTERN VALIDATED & LINE DRAWN", signalType));
            Print("         ═══════════════════════════════════════════════════════");
            Print(StringFormat("         Setup ID: %s", setup.setupID));
            Print(StringFormat("         Wick Size: %.1fp | Body Size: %.1fp | Ratio: %.2f", 
                               setup.wickSize, setup.bodySize, setup.ratio));
            Print(StringFormat("         Band Touched: %s @ %.2f", bandStr, setup.bandPrice));
            Print(StringFormat("         Distance to Band: %.1fp (Tolerance: %.1fp) ✓ WITHIN", 
                               distToBand / pipValue, tolEffPips));
            Print(StringFormat("         Entry Side: %s", setup.isBullish ? "ABOVE band (bullish)" : "BELOW band (bearish)"));
            Print("         ═══════════════════════════════════════════════════════\n");

            // CSV write pass
            if(csv != INVALID_HANDLE) {
                FileWrite(csv,
                    TimeToString(time, TIME_DATE|TIME_MINUTES),
                    (close>open?"BULL":"BEAR"),
                    DoubleToString(open, 2), DoubleToString(high, 2), DoubleToString(low, 2), DoubleToString(close, 2),
                    DoubleToString(bodySizePips, 1), DoubleToString(wickSizePips, 1), DoubleToString(ratio, 2),
                    DoubleToString(bbUpper, 2), DoubleToString(bbMiddle, 2), DoubleToString(bbLower, 2),
                    DoubleToString(tolEffPips, 1),
                    "PASS",
                    "",
                    setup.setupID,
                    bandStr,
                    DoubleToString(distToBand / pipValue, 1)
                );
            }
        } else {
            // Analyze rejection reason
            string rejectReason = "UNKNOWN";
            
            if(!hasBB) {
                rejectReason = "❌ BB_NOT_READY";
            } else if(ratio < InpWickRatioMin && wickSizePips < InpMinWickPips) {
                rejectReason = StringFormat("❌ RATIO_LOW (%.2f < %.2f)", ratio, InpWickRatioMin);
            } else {
                // Pinbar shape exists, check why BB rejected it
                bool isBull = (close > open);
                
                // Check strict band rule
                if(InpStrictBandCheck) {
                    if((bbUpper > bodyLow && bbUpper < bodyHigh) ||
                       (bbMiddle > bodyLow && bbMiddle < bodyHigh) ||
                       (bbLower > bodyLow && bbLower < bodyHigh)) {
                        rejectReason = "❌ STRICT_BAND (band passes through body)";
                    }
                }
                
                // Check distance/side rules
                if(rejectReason == "UNKNOWN") {
                    if(isBull) {
                        double dL = MathAbs(low - bbLower);
                        double dM = MathAbs(low - bbMiddle);
                        if(dL > tolEff && dM > tolEff) {
                            rejectReason = StringFormat("❌ DISTANCE_FAIL (Low too far: dL=%.1fp > tolEff=%.1fp)", dL/pipValue, tolEffPips);
                        } else if(dL <= tolEff && ((InpLenientMode && (open < bbLower && close < bbLower)) || (!InpLenientMode && (open <= bbLower || close <= bbLower)))) {
                            rejectReason = "❌ SIDE_FAIL (Body not above band)";
                        } else if(dM <= tolEff && ((InpLenientMode && (open < bbMiddle && close < bbMiddle)) || (!InpLenientMode && (open <= bbMiddle || close <= bbMiddle)))) {
                            rejectReason = "❌ SIDE_FAIL (Body not above middle)";
                        }
                    } else if(close < open) { // BEAR
                        double dU = MathAbs(high - bbUpper);
                        double dM2 = MathAbs(high - bbMiddle);
                        if(dU > tolEff && dM2 > tolEff) {
                            rejectReason = StringFormat("❌ DISTANCE_FAIL (High too far: dU=%.1fp > tolEff=%.1fp)", dU/pipValue, tolEffPips);
                        } else if(dU <= tolEff && ((InpLenientMode && (open > bbUpper && close > bbUpper)) || (!InpLenientMode && (open >= bbUpper || close >= bbUpper)))) {
                            rejectReason = "❌ SIDE_FAIL (Body not below band)";
                        } else if(dM2 <= tolEff && ((InpLenientMode && (open > bbMiddle && close > bbMiddle)) || (!InpLenientMode && (open >= bbMiddle || close >= bbMiddle)))) {
                            rejectReason = "❌ SIDE_FAIL (Body not below middle)";
                        }
                    }
                }
                
                if(rejectReason == "UNKNOWN") {
                    rejectReason = "❌ BB_LOGIC_FAIL";
                }
            }
            
            // Draw marker on rejected candle for visual debugging
            DrawRejectedCandle(time, high, low, rejectReason);
            
            // Rejection reason logs disabled - focus on accepted patterns only
            // Print(StringFormat("         %s\n", rejectReason));

            // CSV write fail
            if(csv != INVALID_HANDLE) {
                FileWrite(csv,
                    TimeToString(time, TIME_DATE|TIME_MINUTES),
                    (close>open?"BULL":"BEAR"),
                    DoubleToString(open, 2), DoubleToString(high, 2), DoubleToString(low, 2), DoubleToString(close, 2),
                    DoubleToString(bodySizePips, 1), DoubleToString(wickSizePips, 1), DoubleToString(ratio, 2),
                    DoubleToString(bbUpper, 2), DoubleToString(bbMiddle, 2), DoubleToString(bbLower, 2),
                    DoubleToString(tolEffPips, 1),
                    "FAIL",
                    rejectReason,
                    "",
                    "",
                    ""
                );
            }
        }
    }

    if(csv != INVALID_HANDLE) {
        FileClose(csv);
        Print("📝 Historical scan written to ScanLog.csv");
    }
    
    Print("\n╔════════════════════════════════════════════════════════════════╗");
    Print("║                    SCAN SUMMARY                                ║");
    Print(StringFormat("║ Confirmed Patterns: %d", m15BBMatches));
    Print("╚════════════════════════════════════════════════════════════════╝\n");
}

//+------------------------------------------------------------------+
//| Get Stop Reason String                                           |
//+------------------------------------------------------------------+
string GetStopReason(int reason) {
    switch(reason) {
        case REASON_PROGRAM:  return "EA Removed";
        case REASON_ACCOUNT:  return "Account Changed";
        case REASON_CHARTCHANGE: return "Chart Changed";
        case REASON_CHARTCLOSE: return "Chart Closed";
        case REASON_PARAMETERS: return "Inputs Changed";
        case REASON_RECOMPILE: return "EA Recompiled";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| On Chart Event - Handle UI Interactions                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    // Can add buttons, info panels here later
}

//+------------------------------------------------------------------+
//| Helper: Check if bar is pinbar                                   |
//+------------------------------------------------------------------+
bool IsBarPinbar(double open, double high, double low, double close, int tf) {
    double bodySize = MathAbs(close - open);
    double bodyHigh = MathMax(open, close);
    double bodyLow = MathMin(open, close);
    
    double upperWick = high - bodyHigh;
    double lowerWick = bodyLow - low;
    double wickSize = (close > open) ? lowerWick : upperWick; // Bullish = bottom wick, Bearish = top wick
    
    double pipValue = _Point;
    double bodySizePips = bodySize / pipValue;
    double wickSizePips = wickSize / pipValue;
    
    if(bodySizePips == 0) return false;
    
    double ratio = wickSizePips / bodySizePips;
    if(ratio >= InpWickRatioMin) return true;
    if(InpLenientMode && wickSizePips >= InpMinWickPips) return true;
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Get scenario number                                      |
//+------------------------------------------------------------------+
int GetScenarioNumber(double open, double high, double low, double close, int tf) {
    // This is simplified - returns 1 or 2 based on which band interaction
    return (close > open) ? 1 : 2; // Placeholder
}

//+------------------------------------------------------------------+
//| Live detection log for most recent bar                          |
//+------------------------------------------------------------------+
void LogLiveDetection(int timeframe, int barIndex, PinbarSetup &setup) {
    double pipValue = _Point;
    double open = iOpen(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    double high = iHigh(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    double low = iLow(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    double close = iClose(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    datetime time = iTime(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);

    if(open == 0) return;

    double bodySize = MathAbs(close - open);
    double bodyHigh = MathMax(open, close);
    double bodyLow = MathMin(open, close);
    double lowerWick = bodyLow - low;
    double upperWick = high - bodyHigh;
    double wickSize = (close > open) ? lowerWick : upperWick;
    double bodyPips = bodySize / pipValue;
    double wickPips = wickSize / pipValue;
    double ratio = (bodyPips > 0) ? (wickPips / bodyPips) : 0;

    double bbUpper=0, bbMiddle=0, bbLower=0;
    bool hasBB = GetBBValues(g_bbM15Handle, barIndex, bbUpper, bbMiddle, bbLower);
    double atr = hasBB ? GetATR(timeframe, InpBBToleranceAtrPeriod, barIndex + 1) : 0;
    double tolPrice = hasBB ? ComputeTolerancePrice(bbUpper, bbLower, pipValue, atr) : 0;
    double tolEff = tolPrice * (1.0 + InpBBTouchBufferPct);
    double tolEffPips = (pipValue > 0) ? tolEff / pipValue : 0;

    string dirStr = (close > open) ? "🟢 BULL" : (close < open ? "🔴 BEAR" : "⚪ DOJI");
    string timeStr = TimeToString(time, TIME_DATE|TIME_MINUTES);

    Print(StringFormat("[LIVE] %s | %s | O=%.2f H=%.2f L=%.2f C=%.2f | Body=%.1fp Wick=%.1fp Ratio=%.2f",
                       timeStr, dirStr, open, high, low, close, bodyPips, wickPips, ratio));
    Print(StringFormat("       BB: U=%.2f M=%.2f L=%.2f | ATR=%.2f | TolEff=%.1fp",
                       bbUpper, bbMiddle, bbLower, atr, tolEffPips));

    if(setup.setupID != "") {
        double distToBand = setup.isBullish ? MathAbs(low - setup.bandPrice) : MathAbs(high - setup.bandPrice);
        string bandStr = (setup.touchedBand == BAND_LOWER) ? "LOWER" : (setup.touchedBand == BAND_UPPER ? "UPPER" : "MIDDLE");
        string signalType = setup.isBullish ? "🟢 LONG SIGNAL" : "🔴 SHORT SIGNAL";
        
        Print("       ═══════════════════════════════════════════════════════");
        Print(StringFormat("       ✅ %s - LINE DRAWN & TRADE PENDING", signalType));
        Print("       ═══════════════════════════════════════════════════════");
        Print(StringFormat("       Setup ID: %s", setup.setupID));
        Print(StringFormat("       Wick Size: %.1fp | Body Size: %.1fp | Ratio: %.2f", 
                           setup.wickSize, setup.bodySize, setup.ratio));
        Print(StringFormat("       Band Touched: %s @ %.2f", bandStr, setup.bandPrice));
        Print(StringFormat("       Distance to Band: %.1fp (Tolerance: %.1fp) ✓ WITHIN", 
                           distToBand / pipValue, tolEffPips));
        Print(StringFormat("       Entry Side: %s", setup.isBullish ? "ABOVE band (bullish)" : "BELOW band (bearish)"));
        Print("       ═══════════════════════════════════════════════════════\n");
        return;
    }

    // Determine rejection reason (aligned with historical scan logic)
    string rejectReason = "❌ BB_LOGIC_FAIL";

    if(!hasBB) {
        rejectReason = "❌ BB_NOT_READY";
    } else if(ratio < InpWickRatioMin && wickPips < InpMinWickPips) {
        rejectReason = StringFormat("❌ RATIO_LOW (%.2f < %.2f)", ratio, InpWickRatioMin);
    } else {
        bool isBull = (close > open);
        // Strict band through body
        if(InpStrictBandCheck) {
            if((bbUpper > bodyLow && bbUpper < bodyHigh) ||
               (bbMiddle > bodyLow && bbMiddle < bodyHigh) ||
               (bbLower > bodyLow && bbLower < bodyHigh)) {
                rejectReason = "❌ STRICT_BAND (band through body)";
            }
        }

        if(rejectReason == "❌ BB_LOGIC_FAIL") {
            if(isBull) {
                double dL = MathAbs(low - bbLower);
                double dM = MathAbs(low - bbMiddle);
                if(dL > tolEff && dM > tolEff) {
                    rejectReason = StringFormat("❌ DISTANCE_FAIL (Low too far: %.1fp > %.1fp)", dL/pipValue, tolEffPips);
                } else if(dL <= tolEff && ((InpLenientMode && (open < bbLower && close < bbLower)) || (!InpLenientMode && (open <= bbLower || close <= bbLower)))) {
                    rejectReason = "❌ SIDE_FAIL (Body not above lower)";
                } else if(dM <= tolEff && ((InpLenientMode && (open < bbMiddle && close < bbMiddle)) || (!InpLenientMode && (open <= bbMiddle || close <= bbMiddle)))) {
                    rejectReason = "❌ SIDE_FAIL (Body not above middle)";
                }
            } else if(close < open) {
                double dU = MathAbs(high - bbUpper);
                double dM2 = MathAbs(high - bbMiddle);
                if(dU > tolEff && dM2 > tolEff) {
                    rejectReason = StringFormat("❌ DISTANCE_FAIL (High too far: %.1fp > %.1fp)", dU/pipValue, tolEffPips);
                } else if(dU <= tolEff && ((InpLenientMode && (open > bbUpper && close > bbUpper)) || (!InpLenientMode && (open >= bbUpper || close >= bbUpper)))) {
                    rejectReason = "❌ SIDE_FAIL (Body not below upper)";
                } else if(dM2 <= tolEff && ((InpLenientMode && (open > bbMiddle && close > bbMiddle)) || (!InpLenientMode && (open >= bbMiddle || close >= bbMiddle)))) {
                    rejectReason = "❌ SIDE_FAIL (Body not below middle)";
                }
            }
        }
        if(rejectReason == "❌ BB_LOGIC_FAIL") {
            rejectReason = "❌ BB_LOGIC_FAIL"; // unchanged
        }
    }

    // Rejection reason logs disabled - focus on accepted patterns only
    // Print(StringFormat("       %s\n", rejectReason));
}
//+------------------------------------------------------------------+

