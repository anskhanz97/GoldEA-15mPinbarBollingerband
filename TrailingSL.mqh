//+------------------------------------------------------------------+
//|                      TrailingSL.mqh                               |
//|            Optional Trailing Stop Loss Management                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trail All Open Positions                                         |
//+------------------------------------------------------------------+
void TrailAllPositions() {
    if(!InpEnableTrailingSL) return;
    
    double pipValue = GetPipValue();
    double trailDistance = InpTrailDistancePips * pipValue;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        }
        
        double currentSL = PositionGetDouble(POSITION_SL);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in pips
        double profitPips = 0;
        if(posType == POSITION_TYPE_BUY) {
            profitPips = (currentPrice - openPrice) / pipValue;
        } else {
            profitPips = (openPrice - currentPrice) / pipValue;
        }
        
        // ===== BREAK-EVEN MODE =====
        if(InpEnableBreakEven && profitPips >= InpBEStartPips) {
            // Find setup and mark BE
            for(int m = 0; m < ArraySize(g_setups); m++) {
                if(g_setups[m].orderTicket == ticket && !g_setups[m].breakEvenTriggered) {
                    g_setups[m].breakEvenTriggered = true;
                    double beSL = openPrice + (InpBEOffsetPips * pipValue);
                    if(posType == POSITION_TYPE_SELL) {
                        beSL = openPrice - (InpBEOffsetPips * pipValue);
                    }
                    ModifySL(ticket, beSL);
                    break;
                }
            }
        }
        
        // ===== SIMPLE TRAILING =====
        double newSL = 0;
        if(posType == POSITION_TYPE_BUY) {
            newSL = currentPrice - trailDistance;
            if(newSL > currentSL && newSL > openPrice) {
                ModifySL(ticket, newSL);
            }
        } else {
            newSL = currentPrice + trailDistance;
            if(newSL < currentSL || currentSL == 0) {
                if(newSL < openPrice) {
                    ModifySL(ticket, newSL);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
