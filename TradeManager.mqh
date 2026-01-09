//+------------------------------------------------------------------+
//|                       TradeManager.mqh                            |
//|           Simple Market Order & Position Management               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place Market Order for Valid Pinbar Setup                        |
//+------------------------------------------------------------------+
bool PlaceMarketTrade(PinbarSetup &setup) {
    
    if(setup.setupID == "") return false; // Invalid setup
    
    // ===== CALCULATE SL & TP =====
    double pipValue = GetPipValue();
    double slOffsetPips = InpSLOffsetPips;
    double slPips = setup.wickSize + slOffsetPips;
    
    // Apply maximum SL limit if enabled
    if(InpEnableMaxSLLimit && slPips > InpMaxSLPips) {
        slPips = InpMaxSLPips;
    }
    
    double slDistance = slPips * pipValue;
    double tpDistance = InpTPPips * pipValue;
    
    // Calculate SL based on direction
    double stopLoss = 0;
    if(setup.isBullish) {
        stopLoss = setup.wickLow - slDistance; // SL below wick
    } else {
        stopLoss = setup.wickHigh + slDistance; // SL above wick
    }
    
    // TP calculation
    double takeProfit = 0;
    if(setup.isBullish) {
        takeProfit = iClose(_Symbol, (ENUM_TIMEFRAMES)setup.timeframe, 0) + tpDistance;
    } else {
        takeProfit = iClose(_Symbol, (ENUM_TIMEFRAMES)setup.timeframe, 0) - tpDistance;
    }
    
    // ===== PREPARE TRADE REQUEST =====
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = InpLotSize;
    request.type = setup.isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(_Symbol, setup.isBullish ? SYMBOL_ASK : SYMBOL_BID);
    request.sl = NormalizeDouble(stopLoss, _Digits);
    request.tp = NormalizeDouble(takeProfit, _Digits);
    request.comment = setup.setupID;
    request.magic = GenerateMagicNumber(setup);
    
    // ===== SEND ORDER =====
    if(!OrderSend(request, result)) {
        Print("❌ Order FAILED for ", setup.setupID, " | Error: ", GetLastError());
        return false;
    }
    
    if(result.retcode != TRADE_RETCODE_DONE) {
        Print("❌ Order REJECTED for ", setup.setupID, " | Code: ", result.retcode);
        return false;
    }
    
    // ===== ORDER SUCCESSFUL =====
    setup.orderTicket = result.order;
    setup.entryPrice = result.price;
    setup.stopLoss = request.sl;
    setup.takeProfit = request.tp;
    setup.orderTime = TimeCurrent();
    setup.state = SETUP_EXECUTED;
    
    Print("✅ MARKET ORDER PLACED: ", setup.setupID);
    Print("   Direction: ", (setup.isBullish ? "LONG" : "SHORT"));
    Print("   Entry: ", DoubleToString(setup.entryPrice, _Digits));
    Print("   SL: ", DoubleToString(setup.stopLoss, _Digits));
    Print("   TP: ", DoubleToString(setup.takeProfit, _Digits));
    
    if(InpEnableAlerts) {
        Alert("🔔 NEW TRADE: ", setup.setupID, " | ", 
              (setup.isBullish ? "BUY" : "SELL"), " @ ", 
              DoubleToString(setup.entryPrice, _Digits));
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Modify Take Profit                                               |
//+------------------------------------------------------------------+
bool ModifyTP(ulong ticket, double newTP) {
    if(ticket <= 0) return false;
    if(!PositionSelectByTicket(ticket)) return false;
    
    newTP = NormalizeDouble(newTP, _Digits);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.tp = newTP;
    request.sl = PositionGetDouble(POSITION_SL);
    
    if(!OrderSend(request, result)) return false;
    if(result.retcode != TRADE_RETCODE_DONE) return false;
    
    if(InpDebugMode) {
        Print("✅ Modified TP #", ticket, " to ", DoubleToString(newTP, _Digits));
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Modify Stop Loss                                                 |
//+------------------------------------------------------------------+
bool ModifySL(ulong ticket, double newSL) {
    if(ticket <= 0) return false;
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Don't move to worse SL
    if(posType == POSITION_TYPE_BUY && newSL < currentSL && currentSL > 0) return false;
    if(posType == POSITION_TYPE_SELL && newSL > currentSL && currentSL > 0) return false;
    
    newSL = NormalizeDouble(newSL, _Digits);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = newSL;
    request.tp = PositionGetDouble(POSITION_TP);
    
    if(!OrderSend(request, result)) return false;
    if(result.retcode != TRADE_RETCODE_DONE) return false;
    
    if(InpDebugMode) {
        Print("✅ Modified SL #", ticket, " to ", DoubleToString(newSL, _Digits));
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Close Position by Ticket                                         |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string reason) {
    if(ticket <= 0) return false;
    if(!PositionSelectByTicket(ticket)) return false;
    
    double closePrice = SymbolInfoDouble(_Symbol, 
                       PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                       SYMBOL_BID : SYMBOL_ASK);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                   ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = closePrice;
    request.comment = reason;
    
    if(!OrderSend(request, result)) return false;
    if(result.retcode != TRADE_RETCODE_DONE) return false;
    
    Print("✅ Position CLOSED #", ticket, " | Reason: ", reason);
    
    if(InpEnableAlerts) {
        Alert("✅ CLOSED: #", ticket, " | ", reason);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Active Position for Setup                                  |
//+------------------------------------------------------------------+
ulong FindPositionBySetupID(string setupID) {
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        string comment = PositionGetString(POSITION_COMMENT);
        if(comment == setupID) {
            return ticket;
        }
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Check if Position is TP Hit                                      |
//+------------------------------------------------------------------+
bool IsPositionTPHit(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    
    double tp = PositionGetDouble(POSITION_TP);
    if(tp == 0) return false; // No TP set
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    if(type == POSITION_TYPE_BUY) {
        return currentPrice >= tp;
    } else {
        return currentPrice <= tp;
    }
}

//+------------------------------------------------------------------+
//| Helper: Generate Magic Number                                    |
//+------------------------------------------------------------------+
ulong GenerateMagicNumber(PinbarSetup &setup) {
    // Ensure unique magic per setup
    string hashStr = setup.setupID;
    ulong magic = 0;
    
    for(int i = 0; i < StringLen(hashStr); i++) {
        magic = magic * 31 + StringGetCharacter(hashStr, i);
    }
    
    return (magic % 1000000) + 100000; // Range 100000-1099999
}

//+------------------------------------------------------------------+
