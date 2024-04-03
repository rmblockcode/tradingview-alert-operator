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
input int hourStartNY = 9; // Hora de NY de inicio operativo
input int hourEndNY = 13; // Hora de NY de fin operativo
input int differenceOfHourNY = 7; // Diferencia de horas entre tu broker y la hora de Nueva York
input double amountToRiskBuy = 215; // Monto de que deseas arriesgar en operaciones de Compra
input double amountToRiskSell = 225; // Monto de que deseas arriesgar en operaciones de Venta
//input string telegramChatID = "-1111111111111"; // Ingresa tu Telegram Chat ID
//input string telegramBotToken = "700000000:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaXYZ"; // Ingresa tu Telegram API Token

// EJEMPLOS
input string telegramChatID = "-1002011844853"; // Ingresa tu Telegram Chat ID
input string telegramBotToken = "7012376231:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaVaM"; // Ingresa tu Telegram API Token

// User Access
string botUrl = "https://tradingbot-access.onrender.com"; // No editar al menos que sea indicado

// Alerts from Tradingview
string signalUrl = "https://tradingview-alert-operator.onrender.com"; // No editar al menos que sea indicado

int timeout = 5000; // Timeout

bool userAccessValidated = false; // Flag para indicar si el bot esta habilitado para el usuario y la cuenta

bool isOpenPositionInDay = false;
ulong tradeTicketBuy = 0;
ulong tradeTicketSell = 0;

double priceForBE = 0;
double openPriceReal = 0;
bool alreadyInBreakEvenBuy = false; // Flag para indicar que ya se modifico a BreakEven para compras
bool alreadyInBreakEvenSell = false; // Flag para indicar que ya se modifico a BreakEven para ventas 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   sendTelegramMessage("INICIANDO BOT ESTRATEGIA ORO EN LONDRESEN MT4...", telegramChatID, telegramBotToken);
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
   //getSignal();
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
   //getSignal();
   datetime currentTime = TimeCurrent();
   MqlDateTime str;
   TimeToStruct(currentTime, str);

// Horario de Nueva York (NY) - asegúrate de ajustar esto según tu broker
   int NYHour = str.hour - differenceOfHourNY; // Ajuste de zona horaria
   int NYMin = str.min;
   if(NYHour < 0)
      NYHour += 24;

   if(NYHour >= hourEndNY && !isOrderOpen(tradeTicketBuy) && !isOrderOpen(tradeTicketSell)) {
      Print("Fuera de horario operativo!!");
      isOpenPositionInDay = true; // Por si caso reseteamos esta variable
      return;
   }
   
   Print("En horario NY: ", NYHour, ":", NYMin, ":", str.sec);
   //getSignal();
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
   string requestURL = StringFormat("%s/tradingview-alert-gold-londo/signal/%s/%s/", signalUrl, userCode, IntegerToString(accountNumber));
   response = WebRequest("GET",requestURL,cookie,NULL,timeout,post,0,result,headers);

   if(response == -1) {
      Print("Error en WebRequest. Código de error a tradingview-alert/signal: ", GetLastError());
      return;
   }
   
   resultMessage = CharArrayToString(result);
   CJAVal js (NULL, jtUNDEF);
   b = js.Deserialize(resultMessage);
   bool openTrade = js["detail"].ToBool();
   double slPrice = js["sl_price"].ToDbl();
   double tpPrice = js["tp_price"].ToDbl();
   bool close_trade = js["close_trade"].ToBool();
   priceForBE = js["price_for_be"].ToDbl();
   
   if (openTrade == true) { // Se abre operacion
      string signal_type = js["signal_type"].ToStr();
      
      if (signal_type == "buy" && close_trade == false){
      
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(!isOrderOpen(tradeTicketBuy) && isOpenPositionInDay == false){
            // Abriremos compra porque no hay operacion abierta, llego señal y no hay orden de cerrar
            Print("ABRO COMPRA. No hay operacion abierta, llego señal y no hay orden de cerrar");
            
            // First set StopLoss Price
            double lotSize = CalculateLotSize(_Symbol, amountToRiskBuy, slPrice);
   
            trade.Buy(lotSize, _Symbol, currentPrice, slPrice, tpPrice, "[BUY OPENED] XAUUSD Strategy London");
            tradeTicketBuy = trade.ResultOrder();
            
            isOpenPositionInDay = true;
            
            double slReal = PositionGetDouble(POSITION_SL);
            double tpReal = PositionGetDouble(POSITION_TP);
            openPriceReal = PositionGetDouble(POSITION_PRICE_OPEN);
            
            string telegramMessage = StringFormat(
                                 "[COMPRA ACTIVADA] Precios teóricos => Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s | Precios Reales => Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s",
                                 DoubleToString(currentPrice),
                                 DoubleToString(slPrice),
                                 DoubleToString(tpPrice),
                                 DoubleToString(openPriceReal),
                                 DoubleToString(tpReal),
                                 DoubleToString(slReal));
   
            Print(telegramMessage);
   
            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);  
         } else {
            // Hay operacion abierta pero aun no hay señal de cierre, verificamos si ponemos BE
            if(priceForBE > 0 && currentPrice >= priceForBE && alreadyInBreakEvenBuy == false) {
               trade.PositionModify(tradeTicketBuy, openPriceReal, tpPrice);
               alreadyInBreakEvenBuy = true;
            }
         }

      } else if (signal_type == "sell" && close_trade == false){

         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(PositionSelectByTicket(tradeTicketSell) == false && isOpenPositionInDay == false){
            // Abriremos compra porque no hay operacion abierta, llego señal y no hay orden de cerrar
            Print("ABRO VENTA. No hay operacion abierta, llego señal y no hay orden de cerrar");
            double lotSize = CalculateLotSize(_Symbol, amountToRiskSell, slPrice);

            trade.Sell(lotSize, _Symbol, currentPrice, slPrice, tpPrice, "[SELL OPENED] XAUUSD Strategy London");
            tradeTicketSell = trade.ResultOrder();
            
            isOpenPositionInDay = true;
            
            double slReal = PositionGetDouble(POSITION_SL);
            double tpReal = PositionGetDouble(POSITION_TP);
            openPriceReal = PositionGetDouble(POSITION_PRICE_OPEN);
            
            string telegramMessage = StringFormat(
                                 "[VENTA ACTIVADA] Precios teóricos => Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s | Precios Reales => Precio Apertura: %s ; Precio de TP: %s; Precio SL: %s",
                                 DoubleToString(currentPrice),
                                 DoubleToString(tpPrice),
                                 DoubleToString(slPrice),
                                 DoubleToString(openPriceReal),
                                 DoubleToString(tpReal),
                                 DoubleToString(slReal));
   
            Print(telegramMessage);
   
            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         } else {
            // Hay operacion abierta pero aun no hay señal de cierre, verificamos si ponemos BE
            if(priceForBE > 0 && currentPrice <= priceForBE && alreadyInBreakEvenSell == false) {
               trade.PositionModify(tradeTicketSell, openPriceReal, tpPrice);
               alreadyInBreakEvenBuy = true;
            }
         }
      } else if(close_trade == true) {
         // Procedemos a cerrar la operacion que este abierta
         if(PositionSelectByTicket(tradeTicketBuy) == true){
            trade.PositionClose(tradeTicketBuy);
            tradeTicketBuy = 0;
            priceForBE = 0;

            string telegramMessage = "Se ha cerrado la operación de compra";
            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         } else if(PositionSelectByTicket(tradeTicketSell) == true){
            trade.PositionClose(tradeTicketSell);
            tradeTicketSell = 0;
            priceForBE = 0;

            string telegramMessage = "Se ha cerrado la operación de venta";
            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         }
         
      }
   }
   return;
}

bool botAccessValidation(string accountNumber)
  {
   string remainUrl = StringFormat("access-validation/%s/%s/tradingview_alert_bot_enabled/", userCode, accountNumber);

   bool response = botAccessRequest(remainUrl);

   return response;
  }


bool botAccessRequest(string remainUrl) {
   string requestURL = "";
   string cookie=NULL;
   string headers = NULL; // Asegúrate de que los encabezados sean apropiados para tu solicitud
   string resultMessage;
   bool b;
   
   requestURL = StringFormat("%s/%s", botUrl, remainUrl);
   Print("Sending Request to botAccess: ", requestURL);

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
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
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

bool isOrderOpen(ulong ticket) {
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS) && OrderTicket() == ticket) {
            return true; // La orden con el ticket especificado está abierta
        }
    }
    return false; // No se encontró la orden, no está abierta
}
