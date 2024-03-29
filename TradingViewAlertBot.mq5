//+------------------------------------------------------------------+
//|                                          TradingViewAlertBot.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Trade\JAson.mqh>
CTrade trade;

input string signalUrl = "https://tradingview-alert-operator.onrender.com"; // No editar al menos que sea indicado
input string userCode = "joedoe"; // Código de usuario (Solicitar)
//input string telegramChatID = "-1111111111111"; // Ingresa tu Telegram Chat ID
//input string telegramBotToken = "700000000:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaXYZ"; // Ingresa tu Telegram API Token

// EJEMPLOS
input string telegramChatID = "-1002011844853"; // Ingresa tu Telegram Chat ID
input string telegramBotToken = "7012376231:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaVaM"; // Ingresa tu Telegram API Token

// User Access
input string botUrl = "https://tradingbot-access.onrender.com"; // No editar al menos que sea indicado
input int timeout = 5000; // Timeout

bool userAccessValidated = false; // Flag para indicar si el bot esta habilitado para el usuario y la cuenta

bool isOpenPositionInDay = false;
ulong tradeTicket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   //getSignal();
   
   sendTelegramMessage("INICIANDO TRADINGVIEW ALERT BOT...", telegramChatID, telegramBotToken);
   string telegramMessage = "";
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   Print("accountNumber: ", IntegerToString(accountNumber));

   userAccessValidated = botAccessValidation(IntegerToString(accountNumber));
   
   if (userAccessValidated == false){
      telegramMessage = "Bot NO habilitado para esta cuenta.";
      Print(telegramMessage);
      sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
      return(INIT_FAILED);
   }
   
   sendTelegramMessage("¡INICIO DE BOT SATISFACTORIO!", telegramChatID, telegramBotToken);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Limpieza aquí si es necesaria
   string telegramMessage = StringFormat(
      "El bot fue cerrado de la cuenta %s",
   IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
   Print(telegramMessage);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   getSignal();
   return;
  }
//+------------------------------------------------------------------+


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
      long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
      Print("accountNumber: ", IntegerToString(accountNumber));
      requestURL = StringFormat("%s/tradingview-alert/signal/%s/%s/", signalUrl, userCode, IntegerToString(accountNumber));
      int response = WebRequest("GET", requestURL, headers, timeout, posData, resultData, requestHeaders);
   
      string resultMessage = CharArrayToString(resultData);
      CJAVal js (NULL, jtUNDEF);
      b = js.Deserialize(resultMessage);
      bool detail = js["detail"].ToBool();
      string signal_type = js["signal_type"].ToStr();
      string symbol = js["symbol"].ToStr();
      double amount_to_risk = js["amount_to_risk"].ToDbl();
      double sl_pips = js["sl_pips"].ToDbl();
      double sl_price = js["sl_price"].ToDbl();
      double tp_pips = js["tp_pips"].ToDbl();
      double tp_price = js["tp_price"].ToDbl();
            
      bool openTrade = js["detail"].ToBool();
      
      if (openTrade == true) { // Se abre operacion
         string signal_type = js["signal_type"].ToStr();
         
         if (signal_type == "buy"){
            Print("ABRO COMPRA");
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            
            // First set StopLoss Price
            double lotSize = CalculateLotSize(symbol, amount_to_risk, sl_pips, sl_price);
            double stopLossPrice = CalculateSLPrice(symbol, currentPrice, sl_pips, sl_price, true);
            double takeProfitPrice = CalculateTPPrice(symbol, currentPrice, tp_pips, tp_price, true);

            trade.Buy(lotSize, symbol, currentPrice, stopLossPrice, takeProfitPrice, "[BUY OPENED] TradingView Alert Bot");
            tradeTicket = trade.ResultOrder();
            
            string telegramMessage = StringFormat(
                                 "[COMPRA ACTIVADA] Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s",
                                 DoubleToString(currentPrice),
                                 DoubleToString(takeProfitPrice),
                                 DoubleToString(stopLossPrice));

            Print(telegramMessage);

            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);

         } else if (signal_type == "sell"){
            Print("ABRO VENTA");
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double lotSize = CalculateLotSize(symbol, amount_to_risk, sl_pips, sl_price);

            double stopLossPrice = CalculateSLPrice(symbol, currentPrice, sl_pips, sl_price, false);
            double takeProfitPrice = CalculateTPPrice(symbol, currentPrice, tp_pips, tp_price, false);

            trade.Sell(lotSize, symbol, currentPrice, stopLossPrice, takeProfitPrice, "[SELL OPENED] TradingView Alert Bot");
            tradeTicket = trade.ResultOrder();
            
            string telegramMessage = StringFormat(
                                 "[VENTA ACTIVADA] Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s",
                                 DoubleToString(currentPrice),
                                 DoubleToString(takeProfitPrice),
                                 DoubleToString(stopLossPrice));

            Print(telegramMessage);

            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         }
         isOpenPositionInDay = true;
      }
   }

   return;
  }


//+------------------------------------------------------------------+
//| Method that send request to botAccessAPI                         |
//+------------------------------------------------------------------+
bool botAccessRequest(string remainUrl)
  {
   string headers = "";
   string requestURL = "";
   string requestHeaders = "";
   char resultData[];
   char posData[];
   bool b;

   requestURL = StringFormat("%s/%s", botUrl, remainUrl);
   Print("Sending Request to botAccess: ", requestURL);
   int response = WebRequest("GET", requestURL, headers, timeout, posData, resultData, requestHeaders);

   CJAVal js (NULL, jtUNDEF);
   
   string resultMessage = CharArrayToString(resultData);
   string out;
   b = js.Deserialize(resultMessage);
   //js.Serialize(out);
   return js["result"].ToBool();
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Method that validate if the current user is already in use       |
//+------------------------------------------------------------------+
bool botAccessValidation(string accountNumber)
  {
   string headers = "";
   string requestURL = "";
   string requestHeaders = "";
   char resultData[];
   char posData[];

   string remainUrl = StringFormat("access-validation/%s/%s/tradingview_alert_bot_enabled/", userCode, IntegerToString(accountNumber));

   bool response = botAccessRequest(remainUrl);

   return response;
  }

//+------------------------------------------------------------------+
//| Method that sends message via telegram                           |
//+------------------------------------------------------------------+
int sendTelegramMessage(string text, string chatID, string botToken)
  {
   string baseUrl = "https://api.telegram.org";
   string headers = "";
   string requestURL = "";
   string requestHeaders = "";
   char resultData[];
   char posData[];

   requestURL = StringFormat("%s/bot%s/sendmessage?chat_id=%s&text=%s", baseUrl, botToken, chatID, text);
   Print("Sending Telegram Message");
   int response = WebRequest("POST", requestURL, headers, timeout, posData, resultData, requestHeaders);

   string resultMessage = CharArrayToString(resultData);
   Print("Result Message desde Telegram Message: ", resultMessage);

   return response;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Función para calcular el tamaño del lote                         |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double riskAmount, double slPips, double slPrice)
  {
   double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
   double lotSize = 0.0;
   if (slPrice > 0.0){
     double symbol_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
     double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
     Print("slPrice: ", slPrice);
     Print("symbol_bid: ", symbol_bid);
     Print("pipValue: ", pipValue);
     lotSize = riskAmount / (MathAbs(symbol_bid - slPrice) / pointSize);
     Print("lotsize con slprice: ", lotSize);
   }
   else if (slPips > 0.0)
     lotSize = (riskAmount / (slPips * pipValue)) / 10;
   
   // Devolver el tamaño del lote
   int digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   return NormalizeDouble(lotSize, 2);
  }
  

double CalculateSLPrice(string symbol, double currentPrice, double slPips, double slPrice, bool isBuyOrder) {

   if (slPrice > 0.0) return slPrice;
   if (slPips <= 0.0) return 0;
   
   double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  
   Print("digits: ", digits);
   Print("pointSize: ", pointSize);
   Print("slPips en calculate sl price: ", slPips);
   
   if (isBuyOrder) {
     // Para órdenes de compra, el SL está por debajo del precio actual
     double stopLossPrice = NormalizeDouble(currentPrice - slPips * pointSize * 10, digits);
     Print("currentPrice: ", currentPrice);
     Print("stopLossPrice compra: ", stopLossPrice);
     return stopLossPrice;
   } else {
     // Para órdenes de venta, el SL está por encima del precio actual
     double stopLossPrice = NormalizeDouble(currentPrice + slPips * pointSize * 10, digits);
     Print("currentPrice: ", currentPrice);
     Print("stopLossPrice venta: ", stopLossPrice);
     return stopLossPrice;
   }
}

double CalculateTPPrice(string symbol, double currentPrice, double tpPips, double tpPrice, bool isBuyOrder) {
   
   if (tpPrice > 0.0) return tpPrice;
   if (tpPips <= 0.0) return 0;
   
   double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  
   Print("digits: ", digits);
   Print("pointSize: ", pointSize);
   Print("tpPips en calculate TP price: ", tpPips);
   
   if (isBuyOrder) {
     // Para órdenes de compra, el SL está por debajo del precio actual
     double takeProfitPrice = NormalizeDouble(currentPrice + tpPips * pointSize * 10, digits);
     Print("currentPrice: ", currentPrice);
     Print("takeProfitPrice compra: ", takeProfitPrice);
     return takeProfitPrice;
   } else {
     // Para órdenes de venta, el SL está por encima del precio actual
     double takeProfitPrice = NormalizeDouble(currentPrice - tpPips * pointSize * 10, digits);
     Print("currentPrice: ", currentPrice);
     Print("takeProfitPrice venta: ", takeProfitPrice);
     return takeProfitPrice;
   }
}