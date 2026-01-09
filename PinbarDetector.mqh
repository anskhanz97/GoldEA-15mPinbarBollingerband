//+------------------------------------------------------------------+
//|                      PinbarDetector.mqh                           |
//|              Pinbar + Bollinger Bands Detection Logic             |
//+------------------------------------------------------------------+

// Compute ATR value for the given timeframe/shift
double GetATR(int timeframe, int period, int shift) {
    int handle = iATR(_Symbol, (ENUM_TIMEFRAMES)timeframe, period);
    if(handle == INVALID_HANDLE) return 0;
    double atrArr[];
    ArraySetAsSeries(atrArr, true);
    if(CopyBuffer(handle, 0, shift, 1, atrArr) <= 0) return 0;
    return atrArr[0];
}

// Helper: compute blended tolerance in price units using band width, pips, and ATR
double ComputeTolerancePrice(double bbUpper, double bbLower, double pipValue, double atr) {
    double bandWidth = MathAbs(bbUpper - bbLower);
    double baseTol = InpBBToleranceRelative
        ? bandWidth * (InpBBTolerancePct / 100.0)
        : (InpBBTouchTolerance * pipValue);
    double atrTol = (atr > 0.0) ? (InpBBToleranceAtrMult * atr) : 0.0;
    double tol = baseTol + atrTol;
    if(InpLenientMode) tol *= 1.5;
    return tol;
}

// Helper: Generate Setup ID (local copy for pinbar format)
string GenerateSetupID(datetime pinbarTime, bool isBullish, int timeframe) {
    string datePart = TimeToString(pinbarTime, TIME_DATE);    // YYYY.MM.DD
    string timePart = TimeToString(pinbarTime, TIME_MINUTES); // HH:MM
    string tfSuffix = (timeframe == PERIOD_H1) ? "H1" : "15m";
    return "PinbarBB-" + datePart + "-" + timePart + "-" + tfSuffix;
}

//+------------------------------------------------------------------+
//| Detect Pinbar Pattern on Current Candle                          |
//| Returns: PinbarSetup struct if valid, empty struct if invalid    |
//| If InpCheckBothWicks=true: checks BOTH wicks independently      |
//+------------------------------------------------------------------+
PinbarSetup DetectPinbar(int timeframe) {
    PinbarSetup setup;
    
    // Get current candle (index 0 = current/closing)
    double open = iOpen(_Symbol, (ENUM_TIMEFRAMES)timeframe, 0);
    double high = iHigh(_Symbol, (ENUM_TIMEFRAMES)timeframe, 0);
    double low = iLow(_Symbol, (ENUM_TIMEFRAMES)timeframe, 0);
    double close = iClose(_Symbol, (ENUM_TIMEFRAMES)timeframe, 0);
    datetime time = iTime(_Symbol, (ENUM_TIMEFRAMES)timeframe, 0);
    
    // Calculate wick and body
    double bodyHigh = MathMax(open, close);
    double bodyLow = MathMin(open, close);
    double bodySize = MathAbs(close - open);
    double upperWick = high - bodyHigh;
    double lowerWick = bodyLow - low;
    
    double pipValue = GetPipValue();
    double bodySizePips = bodySize / pipValue;
    if(bodySizePips == 0) return setup; // Doji
    
    // ===== GET BOLLINGER BANDS =====
    int bbHandle = iBands(_Symbol, (ENUM_TIMEFRAMES)timeframe, BB_PERIOD, 0, BB_DEVIATION, PRICE_CLOSE);
    if(bbHandle == INVALID_HANDLE) return setup;
    
    double bbUpperArr[], bbMiddleArr[], bbLowerArr[];
    ArraySetAsSeries(bbUpperArr, true);
    ArraySetAsSeries(bbMiddleArr, true);
    ArraySetAsSeries(bbLowerArr, true);
    
    if(CopyBuffer(bbHandle, 1, 0, 1, bbUpperArr) <= 0) return setup; // Upper band
    if(CopyBuffer(bbHandle, 0, 0, 1, bbMiddleArr) <= 0) return setup; // Middle band
    if(CopyBuffer(bbHandle, 2, 0, 1, bbLowerArr) <= 0) return setup; // Lower band
    
    double bbUpper = bbUpperArr[0];
    double bbMiddle = bbMiddleArr[0];
    double bbLower = bbLowerArr[0];
    
    if(bbUpper == 0 || bbMiddle == 0 || bbLower == 0) return setup; // BB not ready

    // ATR from the previous closed bar for stability
    double atr = GetATR(timeframe, InpBBToleranceAtrPeriod, 1);
    double tolPrice = ComputeTolerancePrice(bbUpper, bbLower, pipValue, atr);
    double tolEff = tolPrice * (1.0 + InpBBTouchBufferPct);
    
    // ===== VALIDATION: Band Through Body Check =====
    if(InpStrictBandCheck) {
        if(IsBandThroughBody(open, close, bbUpper, bbMiddle, bbLower)) {
            return setup; // Band passes through body - invalid
        }
    }
    
    // ===== CHECK LOWER WICK (LONG signals) =====
    if(lowerWick > 0) {
        double lowerWickPips = lowerWick / pipValue;
        double lowerRatio = lowerWickPips / bodySizePips;
        
        if(lowerRatio >= InpWickRatioMin || lowerWickPips >= InpMinWickPips) {
            // Primary target: lower band. Require wick tip to reach or pierce band within tolerance and body above band.
            double distDirLower = bbLower - low; // positive when wick pierces/touches lower band
            bool sideOkLower = InpLenientMode ? (bodyLow >= bbLower) : (bodyLow > bbLower);
            if(distDirLower >= 0 && distDirLower <= tolEff && sideOkLower) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, true, 1);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = true;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = lowerWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = lowerRatio;
                setup.touchedBand = BAND_LOWER;
                setup.bandPrice = bbLower;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
            
            // Secondary target: middle band if price is on that side
            double distDirMiddle = bbMiddle - low;
            bool sideOkMiddle = InpLenientMode ? (bodyLow >= bbMiddle) : (bodyLow > bbMiddle);
            if(distDirMiddle >= 0 && distDirMiddle <= tolEff && sideOkMiddle) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, true, 2);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = true;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = lowerWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = lowerRatio;
                setup.touchedBand = BAND_MIDDLE;
                setup.bandPrice = bbMiddle;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
        }
    }
    
    // ===== CHECK UPPER WICK (SHORT signals) =====
    if(upperWick > 0) {
        double upperWickPips = upperWick / pipValue;
        double upperRatio = upperWickPips / bodySizePips;
        
        if(upperRatio >= InpWickRatioMin || upperWickPips >= InpMinWickPips) {
            // Primary target: upper band. Require wick tip to reach or pierce band within tolerance and body below band.
            double distDirUpper = high - bbUpper; // positive when wick pierces/touches upper band
            bool sideOkUpper = InpLenientMode ? (bodyHigh <= bbUpper) : (bodyHigh < bbUpper);
            if(distDirUpper >= 0 && distDirUpper <= tolEff && sideOkUpper) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, false, 1);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = false;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = upperWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = upperRatio;
                setup.touchedBand = BAND_UPPER;
                setup.bandPrice = bbUpper;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
            
            // Secondary target: middle band if price is on that side
            double distDirMiddleUpper = high - bbMiddle;
            bool sideOkMiddleUpper = InpLenientMode ? (bodyHigh <= bbMiddle) : (bodyHigh < bbMiddle);
            if(distDirMiddleUpper >= 0 && distDirMiddleUpper <= tolEff && sideOkMiddleUpper) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, false, 2);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = false;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = upperWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = upperRatio;
                setup.touchedBand = BAND_MIDDLE;
                setup.bandPrice = bbMiddle;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
        }
    }
    
    return setup; // No valid scenario found
}

//+------------------------------------------------------------------+
//| Helper: Check if Wick Touches Band (within tolerance)            |
//+------------------------------------------------------------------+
bool DoesBandInteract(double wickExtreme, double bandValue, double tolerancePips) {
    return MathAbs(wickExtreme - bandValue) <= tolerancePips;
}

//+------------------------------------------------------------------+
//| Helper: Validate Band NOT Passing Through Body                   |
//+------------------------------------------------------------------+
bool IsBandThroughBody(double open, double close, double bbUpper, double bbMiddle, double bbLower) {
    double bodyHigh = MathMax(open, close);
    double bodyLow = MathMin(open, close);
    
    // Check if any band is between open and close (passes through)
    if((bbUpper > bodyLow && bbUpper < bodyHigh) ||
       (bbMiddle > bodyLow && bbMiddle < bodyHigh) ||
       (bbLower > bodyLow && bbLower < bodyHigh)) {
        return true; // Band passes through body - INVALID
    }
    
    return false; // OK - band does NOT pass through
}

//+------------------------------------------------------------------+
//| Helper: Generate Setup ID with scenario                          |
//+------------------------------------------------------------------+
string GenerateSetupIDWithScenario(int timeframe, datetime formationTime, bool isBullish, int scenario) {
    string base = GenerateSetupID(formationTime, isBullish, timeframe);
    if(scenario > 1) {
        base += "-S" + IntegerToString(scenario);
    }
    return base;
}

//+------------------------------------------------------------------+
//| Helper: Get Pip Value                                            |
//+------------------------------------------------------------------+
double GetPipValue() {
    return _Point;
}

//+------------------------------------------------------------------+
//| Detect Pinbar Pattern on Historical Candle                       |
//| Parameters: timeframe, barIndex (0 = current, 1 = previous, etc) |
//| If InpCheckBothWicks=true: checks BOTH wicks independently      |
//+------------------------------------------------------------------+
PinbarSetup DetectPinbar(int timeframe, int barIndex) {
    PinbarSetup setup;
    
    if(barIndex < 0) return setup;
    
    // Get candle data at specified index
    double open = iOpen(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    double high = iHigh(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    double low = iLow(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    double close = iClose(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    datetime time = iTime(_Symbol, (ENUM_TIMEFRAMES)timeframe, barIndex);
    
    if(open == 0 || high == 0 || low == 0 || close == 0) return setup;
    
    // Calculate wick and body
    double bodyHigh = MathMax(open, close);
    double bodyLow = MathMin(open, close);
    double bodySize = MathAbs(close - open);
    double upperWick = high - bodyHigh;
    double lowerWick = bodyLow - low;
    
    double pipValue = GetPipValue();
    double bodySizePips = bodySize / pipValue;
    if(bodySizePips == 0) return setup; // Doji
    
    // ===== GET BOLLINGER BANDS =====
    int bbHandle = iBands(_Symbol, (ENUM_TIMEFRAMES)timeframe, BB_PERIOD, 0, BB_DEVIATION, PRICE_CLOSE);
    if(bbHandle == INVALID_HANDLE) return setup;
    
    double bbUpperArr[], bbMiddleArr[], bbLowerArr[];
    ArraySetAsSeries(bbUpperArr, true);
    ArraySetAsSeries(bbMiddleArr, true);
    ArraySetAsSeries(bbLowerArr, true);
    
    int copiedUpper = CopyBuffer(bbHandle, 1, barIndex, 1, bbUpperArr);
    int copiedMiddle = CopyBuffer(bbHandle, 0, barIndex, 1, bbMiddleArr);
    int copiedLower = CopyBuffer(bbHandle, 2, barIndex, 1, bbLowerArr);
    
    if(copiedUpper <= 0 || copiedMiddle <= 0 || copiedLower <= 0) return setup;
    
    double bbUpper = bbUpperArr[0];
    double bbMiddle = bbMiddleArr[0];
    double bbLower = bbLowerArr[0];
    
    if(bbUpper == 0 || bbMiddle == 0 || bbLower == 0) return setup;

    // ATR at the bar following this historical index for stability
    double atr = GetATR(timeframe, InpBBToleranceAtrPeriod, barIndex + 1);
    double tolPrice = ComputeTolerancePrice(bbUpper, bbLower, pipValue, atr);
    double tolEff = tolPrice; // No buffer when using fixed pips tolerance
    
    // ===== VALIDATION: Band Through Body Check =====
    if(InpStrictBandCheck) {
        if(IsBandThroughBody(open, close, bbUpper, bbMiddle, bbLower)) {
            return setup;
        }
    }
    
    // ===== CHECK LOWER WICK (LONG signals) =====
    if(lowerWick > 0) {
        double lowerWickPips = lowerWick / pipValue;
        double lowerRatio = lowerWickPips / bodySizePips;
        
        if(lowerRatio >= InpWickRatioMin) {
            double distDirLower = bbLower - low;
            if(distDirLower >= 0 && distDirLower <= tolEff && bodyLow > bbLower) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, true, 1);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = true;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = lowerWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = lowerRatio;
                setup.touchedBand = BAND_LOWER;
                setup.bandPrice = bbLower;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
            
            double distDirMiddle = bbMiddle - low;
            if(distDirMiddle >= 0 && distDirMiddle <= tolEff && bodyLow > bbMiddle) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, true, 2);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = true;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = lowerWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = lowerRatio;
                setup.touchedBand = BAND_MIDDLE;
                setup.bandPrice = bbMiddle;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
        }
    }
    
    // ===== CHECK UPPER WICK (SHORT signals) =====
    if(upperWick > 0) {
        double upperWickPips = upperWick / pipValue;
        double upperRatio = upperWickPips / bodySizePips;
        
        if(upperRatio >= InpWickRatioMin) {
            double distDirUpper = high - bbUpper;
            if(distDirUpper >= 0 && distDirUpper <= tolEff && bodyHigh < bbUpper) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, false, 1);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = false;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = upperWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = upperRatio;
                setup.touchedBand = BAND_UPPER;
                setup.bandPrice = bbUpper;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
            
            double distDirMiddleUpper = high - bbMiddle;
            if(distDirMiddleUpper >= 0 && distDirMiddleUpper <= tolEff && bodyHigh < bbMiddle) {
                setup.setupID = GenerateSetupIDWithScenario(timeframe, time, false, 2);
                setup.formationTime = time;
                setup.timeframe = timeframe;
                setup.isBullish = false;
                setup.wickLow = low;
                setup.wickHigh = high;
                setup.candleOpen = open;
                setup.candleClose = close;
                setup.wickSize = upperWickPips;
                setup.bodySize = bodySizePips;
                setup.ratio = upperRatio;
                setup.touchedBand = BAND_MIDDLE;
                setup.bandPrice = bbMiddle;
                setup.bbUpper = bbUpper;
                setup.bbMiddle = bbMiddle;
                setup.bbLower = bbLower;
                setup.state = SETUP_PENDING;
                return setup;
            }
        }
    }
    
    return setup;
}
