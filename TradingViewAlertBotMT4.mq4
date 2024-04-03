//+------------------------------------------------------------------+
//|                                       TradingViewAlertBotMT4.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include <stdlib.mqh>
#include <JAson.mqh>



input string userCode = "joedoe"; // Código de usuario (Solicitar)
input int slippage = 3; // Diferencia máxima en puntos entre el precio solicitado y el ejecutado
//input string telegramChatID = "-1111111111111"; // Ingresa tu Telegram Chat ID
//input string telegramBotToken = "700000000:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaXYZ"; // Ingresa tu Telegram API Token

// EJEMPLOS
input string telegramChatID = "-1002011844853"; // Ingresa tu Telegram Chat ID
input string telegramBotToken = "7012376231:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaVaM"; // Ingresa tu Telegram API Token

// User Access
string botUrl = "https://tradingbot-access.onrender.com"; // No editar al menos que sea indicado
int timeout = 5000; // Timeout


string signalUrl = "https://tradingview-alert-operator.onrender.com"; // No editar al menos que sea indicado
bool isOpenPositionInDay = false;
bool userAccessValidated = false; // Flag para indicar si el bot esta habilitado para el usuario y la cuenta

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   sendTelegramMessage("INICIANDO TRADINGVIEW ALERT BOT EN MT4...", telegramChatID, telegramBotToken);
   string telegramMessage = "";
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);

   userAccessValidated = botAccessValidation(IntegerToString(accountNumber));
   
   if (userAccessValidated == false){
      telegramMessage = "Bot NO habilitado para esta cuenta.";
      Print(telegramMessage);
      sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
      return(INIT_FAILED);
   }
   
   sendTelegramMessage("¡INICIO DE BOT SATISFACTORIO!", telegramChatID, telegramBotToken);
   getSignal();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
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

void getSignal() {
   string cookie=NULL;
   string headers;
   string data; // En MQL4, posData debe ser un string vacío para GET
   char result[];
   char post[];
   string resultMessage;
   int response;
   bool b;

   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string requestURL = StringFormat("%s/tradingview-alert/signal/%s/%s/", signalUrl, userCode, IntegerToString(accountNumber));
   response = WebRequest("GET",requestURL,cookie,NULL,timeout,post,0,result,headers);

   if(response == -1) {
      Print("Error en WebRequest. Código de error a tradingview-alert/signal: ", GetLastError());
      return;
   }
   
   resultMessage = CharArrayToString(result);
   CJAVal js (NULL, jtUNDEF);
   b = js.Deserialize(resultMessage);
   bool openTrade = js["detail"].ToBool();
   string signal_type = js["signal_type"].ToStr();
   string symbol = js["symbol"].ToStr();
   double amount_to_risk = js["amount_to_risk"].ToDbl();
   double sl_pips = js["sl_pips"].ToDbl();
   double sl_price = js["sl_price"].ToDbl();
   double tp_pips = js["tp_pips"].ToDbl();
   double tp_price = js["tp_price"].ToDbl();
   
   Print("openTrade: ", openTrade);
   Print("signal_type: ", signal_type);
   Print("symbol: ", symbol);
   Print("amount_to_risk: ", amount_to_risk);
   Print("sl_pips: ", sl_pips);
   Print("sl_price: ", sl_price);
   Print("tp_pips: ", tp_pips);
   Print("tp_price: ", tp_price);
   
   if (openTrade == true) { // Se abre operacion
      string signal_type = js["signal_type"].ToStr();
      
      if (signal_type == "buy"){
         Print("ABRO COMPRA");
         double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
         
         // Calcula el tamaño del lote, precio de stop loss y take profit como antes
         double lotSize = CalculateLotSize(symbol, amount_to_risk, sl_pips, sl_price);
         double stopLossPrice = CalculateSLPrice(symbol, currentPrice, sl_pips, sl_price, true);
         double takeProfitPrice = CalculateTPPrice(symbol, currentPrice, tp_pips, tp_price, true);
         
         Print("currentPrice: ", currentPrice);
         Print("stopLossPrice: ", stopLossPrice);
         Print("takeProfitPrice: ", takeProfitPrice);
         // Usa OrderSend para abrir una compra
         int ticket = OrderSend(symbol, OP_BUY, lotSize, currentPrice, slippage, stopLossPrice, takeProfitPrice, "[BUY OPENED] TradingView Alert Bot", 0, 0, clrGreen);
         
         if(ticket < 0) {
            Print("Error al abrir una operación de compra: ", GetLastError());
         } else {
            Print("Operación de compra abierta con éxito. Ticket: ", ticket);
            string telegramMessage = StringFormat(
                              "[COMPRA ACTIVADA MT4] Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s",
                              DoubleToString(currentPrice),
                              DoubleToString(takeProfitPrice),
                              DoubleToString(stopLossPrice));

            Print(telegramMessage);

            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         }
      } else if (signal_type == "sell"){
         Print("ABRO VENTA");
         double currentPrice = MarketInfo(symbol, MODE_BID);
         double lotSize = CalculateLotSize(symbol, amount_to_risk, sl_pips, sl_price);
         Print("LotSize: ", lotSize);
         
         double stopLossPrice = CalculateSLPrice(symbol, currentPrice, sl_pips, sl_price, false);
         double takeProfitPrice = CalculateTPPrice(symbol, currentPrice, tp_pips, tp_price, false);
         
         Print("currentPrice: ", currentPrice);
         Print("stopLossPrice: ", stopLossPrice);
         Print("takeProfitPrice: ", takeProfitPrice);
         
         // Usa OrderSend para abrir una venta
         int ticket = OrderSend(symbol, OP_SELL, lotSize, currentPrice, slippage, stopLossPrice, takeProfitPrice, "[SELL OPENED] TradingView Alert Bot", 0, 0, clrRed);
         
         if(ticket < 0) {
            Print("Error al abrir una operación de venta: ", GetLastError());
         } else {
            Print("Operación de venta abierta con éxito. Ticket: ", ticket);

            string telegramMessage = StringFormat(
                              "[VENTA ACTIVADA MT4] Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s",
                              DoubleToString(currentPrice),
                              DoubleToString(takeProfitPrice),
                              DoubleToString(stopLossPrice));

            Print(telegramMessage);

            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         }
      }
      
      isOpenPositionInDay = true;
   }
}

bool botAccessValidation(string accountNumber)
  {
   string remainUrl = StringFormat("access-validation/%s/%s/tradingview_alert_bot_enabled/", userCode, IntegerToString(accountNumber));

   bool response = botAccessRequest(remainUrl);

   return response;
  }


bool botAccessRequest(string remainUrl) {
   string requestURL = "";
   string cookie=NULL;
   int timeout = 5000; // Define un timeout para la solicitud WebRequest
   string headers = NULL; // Asegúrate de que los encabezados sean apropiados para tu solicitud
   string resultMessage;
   bool b;
   
   requestURL = StringFormat("%s/%s", botUrl, remainUrl);
   Print("Sending Request to botAccess: ", requestURL);

   int resultSize;
   char post[]; // POST data, vacío para una solicitud GET
   char result[]; // Buffer para los datos recibidos
   
   // MQL4 utiliza una función diferente para WebRequest. Observa que no hay manera directa de recibir los encabezados de respuesta
   requestURL = StringFormat("%s/%s", botUrl, remainUrl);
   int response = WebRequest("GET",requestURL,cookie,NULL,timeout,post,0,result,headers);
   
   if(response == -1) {
      Print("Error en WebRequest. Código de error: ", GetLastError());
      return false; // Retorna -1 o un código de error específico
   }

   // Convierte el array de resultado a string. Ten en cuenta que esto es una simplificación y puede no manejar todos los casos correctamente.

   // Aquí necesitarías procesar el resultado JSON manualmente o con una librería adecuada
   // La conversión directa de CJAVal y su uso no es posible en MQL4 sin una biblioteca compatible.

   CJAVal js (NULL, jtUNDEF);
   
   resultMessage = CharArrayToString(result);
   string out;
   b = js.Deserialize(resultMessage);
   //js.Serialize(out);
   return js["result"].ToBool();
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
//| Función para calcular el tamaño del lote                         |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double riskAmount, double slPips, double slPrice)
  {
   double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
   double lotSize = 0.0;
   if (slPrice > 0.0){
     double symbol_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
     double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
     lotSize = riskAmount / (MathAbs(symbol_bid - slPrice) / pointSize);
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
   
   double pointSize = MarketInfo(symbol,MODE_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  
   Print("digits: ", digits);
   Print("Digits: ", Digits);
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