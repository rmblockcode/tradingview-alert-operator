//+------------------------------------------------------------------+
//|                                          TradingViewAlertBot.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\JAson.mqh>
input string signalUrl = "https://tradingview-alert-operator.onrender.com"; // No editar al menos que sea indicado
input string userCode = "joedoe"; // Código de usuario (Solicitar)

bool isOpenPositionInDay = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   //getSignal();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double slPrice = CalculateSLPrice(currentPrice, 35, true);
   Print("Symbol: ", _Symbol);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   //getSignal();
   return;
  }
//+------------------------------------------------------------------+


double CalculateSLPrice(double currentPrice, int slPips, bool isBuyOrder) {
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  
   Print("digits: ", digits);
   Print("currentPrice: ", currentPrice);
   Print("pointSize: ", pointSize);
   
   if (isBuyOrder) {
     // Para órdenes de compra, el SL está por debajo del precio actual
     double stopLossPrice = NormalizeDouble(currentPrice - slPips * pointSize, digits);
     Print("stopLossPrice compra: ", stopLossPrice);
     return stopLossPrice;
   } else {
     // Para órdenes de venta, el SL está por encima del precio actual
     double stopLossPrice = NormalizeDouble(currentPrice + slPips * pointSize, digits);
     Print("stopLossPrice venta: ", stopLossPrice);
     return stopLossPrice;
   }
}


void getSignal()
  {
   string headers = "";
   string requestURL = "";
   string requestHeaders = "";
   char resultData[];
   char posData[];
   int timeout=2000;
   bool b;


   if (isOpenPositionInDay == false) {
      requestURL = StringFormat("%s/tradingview-alert/signal/%s/", signalUrl, userCode);
      int response = WebRequest("GET", requestURL, headers, timeout, posData, resultData, requestHeaders);
   
      string resultMessage = CharArrayToString(resultData);
      CJAVal js (NULL, jtUNDEF);
      b = js.Deserialize(resultMessage);
      Print("detail: ", js["detail"].ToBool());
      Print("signal_type: ", js["signal_type"].ToStr());
      Print("sl_points: ", js["sl_points"].ToStr());
      bool openTrade = js["detail"].ToBool();
      
      if (openTrade == true) { // Se abre operacion
         string signal_type = js["signal_type"].ToStr();
         
         if (signal_type == "buy"){
            Print("ABRO COMPRA");
         } else if (signal_type == "sell"){
            Print("ABRO VENTA");
         }
         isOpenPositionInDay = true;
      }
   }

   return;
  }
