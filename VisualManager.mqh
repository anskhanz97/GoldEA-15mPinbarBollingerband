//+------------------------------------------------------------------+
//|                      VisualManager.mqh                            |
//|             Vertical Line Drawing for Pinbar Setups               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Vertical Line for Pinbar Setup (Timeframe-Specific)         |
//+------------------------------------------------------------------+
void DrawPinbarLine(PinbarSetup &setup) {
    if(setup.setupID == "") return;
    
    // Get current chart timeframe
    int currentTF = (int)_Period;
    
    // Only draw if setup matches current timeframe unless user allows all TF
    if(!InpDrawAllTimeframes && setup.timeframe != currentTF) {
        return; // Setup is from a different timeframe - don't draw on this chart
    }
    
    string lineName = setup.setupID; // Use clean setup ID directly for object name
    setup.lineName = lineName;
    
    // Determine color
    color lineColor = setup.isBullish ? clrGreen : clrRed;

    // Delete any existing object with same name
    ObjectDelete(0, lineName);

    // Create vertical line at formation time (full height)
    if(!ObjectCreate(0, lineName, OBJ_VLINE, 0, setup.formationTime, 0)) {
        Print("Failed to create line: ", lineName);
        return;
    }

    // Set line properties for visibility (dashed + bold)
    ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, false);
    
    if(InpDebugMode) {
        Print("📍 Drew line: ", lineName, " at ", 
              TimeToString(setup.formationTime, TIME_DATE|TIME_MINUTES));
    }
}

//+------------------------------------------------------------------+
//| Redraw Historical Lines (14-day history) with Detailed Logging   |
//+------------------------------------------------------------------+
void RedrawHistoricalLines() {
    // Draw all 15m setups with detailed information
    Print("\n╔════════════════════════════════════════════════════════════════╗");
    Print("║              HISTORICAL VALIDATED PATTERNS                     ║");
    Print("╚════════════════════════════════════════════════════════════════╝\n");
    
    for(int i = 0; i < ArraySize(g_setups); i++) {
        if(g_setups[i].setupID != "") {
            DrawPinbarLine(g_setups[i]);
            
            // Print detailed info for each validated setup
            string signalType = g_setups[i].isBullish ? "🟢 LONG SIGNAL" : "🔴 SHORT SIGNAL";
            string bandStr = (g_setups[i].touchedBand == BAND_LOWER) ? "LOWER" : 
                            (g_setups[i].touchedBand == BAND_UPPER ? "UPPER" : "MIDDLE");
            
            Print("         ═══════════════════════════════════════════════════════");
            Print(StringFormat("         ✅ %s - VALIDATED & LINE DRAWN", signalType));
            Print("         ═══════════════════════════════════════════════════════");
            Print(StringFormat("         Setup ID: %s", g_setups[i].setupID));
            Print(StringFormat("         Time: %s", TimeToString(g_setups[i].formationTime, TIME_DATE|TIME_MINUTES)));
            Print(StringFormat("         Wick Size: %.1fp | Body Size: %.1fp | Ratio: %.2f", 
                               g_setups[i].wickSize, g_setups[i].bodySize, g_setups[i].ratio));
            Print(StringFormat("         Entry Price: Open=%.2f, Close=%.2f", 
                               g_setups[i].candleOpen, g_setups[i].candleClose));
            Print(StringFormat("         Band Touched: %s @ %.2f", bandStr, g_setups[i].bandPrice));
            Print(StringFormat("         BB Levels: Upper=%.2f | Mid=%.2f | Lower=%.2f", 
                               g_setups[i].bbUpper, g_setups[i].bbMiddle, g_setups[i].bbLower));
            Print(StringFormat("         Entry Side: %s", 
                               g_setups[i].isBullish ? "ABOVE band (bullish)" : "BELOW band (bearish)"));
            Print("         ═══════════════════════════════════════════════════════\n");
        }
    }
    
    Print("\n╔════════════════════════════════════════════════════════════════╗");
    Print("║                    SUMMARY                                     ║");
    Print(StringFormat("║ Total Historical Patterns: %d", ArraySize(g_setups)));
    Print("╚════════════════════════════════════════════════════════════════╝\n");
}

//+------------------------------------------------------------------+
//| Delete All Pinbar Lines (any object type)                        |
//+------------------------------------------------------------------+
void DeleteAllPinbarLines() {
    int deleted = 0;
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "PinbarBB-") == 0 || StringFind(objName, "Pinbar_") == 0 || StringFind(objName, "Rejected_") == 0) {
            if(ObjectDelete(0, objName)) deleted++;
        }
    }
    
    if(InpDebugMode) {
        Print("🗑️  Deleted ", deleted, " pinbar lines");
    }
}

//+------------------------------------------------------------------+
//| Draw Rejected Candle Marker (for debugging/visual analysis)      |
//+------------------------------------------------------------------+
void DrawRejectedCandle(datetime barTime, double high, double low, string rejectionReason) {
    if(!InpDrawRejectedCandles) return;
    
    // Create unique marker name
    string markerName = "Rejected_" + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
    
    // Delete any existing marker
    ObjectDelete(0, markerName);
    
    // Draw small orange marker arrow at the high or low based on reason
    double markerPrice = (StringFind(rejectionReason, "too far") >= 0 && StringFind(rejectionReason, "High") >= 0) ? high : low;
    
    if(!ObjectCreate(0, markerName, OBJ_ARROW_DOWN, 0, barTime, markerPrice)) {
        return; // Silent fail
    }
    
    // Small marker (down arrow) - orange color
    ObjectSetInteger(0, markerName, OBJPROP_COLOR, InpRejectedColor);
    ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, markerName, OBJPROP_BACK, true);
    ObjectSetInteger(0, markerName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, markerName, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
