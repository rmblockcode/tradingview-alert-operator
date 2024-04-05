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


input string userCode = "joedoe"; // Código de usuario (Solicitar)
input int hourStartNY = 3; // Hora de NY de inicio operativo
input int hourEndNY = 6; // Hora de NY de fin operativo
input int differenceOfHourNY = 7; // Diferencia de horas entre tu broker y la hora de Nueva York
//input string telegramChatID = "-1111111111111"; // Ingresa tu Telegram Chat ID
//input string telegramBotToken = "700000000:AAFabuLwS7y5L6E7vz6_LGCHA7SP87GaXYZ"; // Ingresa tu Telegram API Token
input double amountToRiskBuy = 215; // Monto de que deseas arriesgar en operaciones de Compra
input double amountToRiskSell = 225; // Monto de que deseas arriesgar en operaciones de Venta

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
double amountToAddToTPSL = 0.75; // Cantidad a sumarle o restarle al SL para que pueda tomar el valor del de tradingview y no cerrar antes 
double priceForBE = 0;
double openPriceReal = 0;
bool alreadyInBreakEvenBuy = false; // Flag para indicar que ya se modifico a BreakEven para compras
bool alreadyInBreakEvenSell = false; // Flag para indicar que ya se modifico a BreakEven para ventas 
string accountStr = "";
int decimalDigits = 2;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   //getSignal();
   
   sendTelegramMessage("INICIANDO BOT ESTRATEGIA ORO EN LONDRES...", telegramChatID, telegramBotToken);
   string telegramMessage = "";
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   Print("accountNumber: ", IntegerToString(accountNumber));
   
   accountStr = IntegerToString(accountNumber);

   userAccessValidated = botAccessValidation(accountStr);
   
   if (userAccessValidated == false){
      telegramMessage = "Bot NO habilitado para esta cuenta.";
      Print(telegramMessage);
      sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
      return(INIT_FAILED);
   }
   
   string message = StringFormat("¡INICIO DE BOT SATISFACTORIO EN CUENTA: %s!", accountStr);
   sendTelegramMessage(message, telegramChatID, telegramBotToken);
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

   datetime currentTime = TimeCurrent();
   MqlDateTime str;
   TimeToStruct(currentTime, str);

// Horario de Nueva York (NY) - asegúrate de ajustar esto según tu broker
   int NYHour = str.hour - differenceOfHourNY; // Ajuste de zona horaria
   int NYMin = str.min;
   if(NYHour < 0)
      NYHour += 24;

   if(NYHour >= hourEndNY && PositionSelectByTicket(tradeTicketBuy) == false && PositionSelectByTicket(tradeTicketSell) == false) {
      Print("Fuera de horario operativo!!");
      isOpenPositionInDay = true; // Por si caso reseteamos esta variable
      return;
   }
   
   Print("En horario NY: ", NYHour, ":", NYMin, ":", str.sec);
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
   bool b;

   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   
   requestURL = StringFormat("%s/tradingview-alert-gold-london/signal/%s/%s/", signalUrl, userCode, IntegerToString(accountNumber));
   int response = WebRequest("GET", requestURL, headers, timeout, posData, resultData, requestHeaders);

   string resultMessage = CharArrayToString(resultData);
   CJAVal js (NULL, jtUNDEF);
   b = js.Deserialize(resultMessage);
   bool openTrade = js["detail"].ToBool();
   double slPrice = js["sl_price"].ToDbl();
   double tpPrice = js["tp_price"].ToDbl();
   bool close_trade = js["close_trade"].ToBool();
   bool set_be = js["set_be"].ToBool(); // Flag que indica si poner BE o no
   double slPips = js["sl_pips"].ToDbl();
   priceForBE = js["price_for_be"].ToDbl();
   
   if (openTrade == true) { // Se abre operacion
      string signal_type = js["signal_type"].ToStr();
      
      if (signal_type == "buy" && close_trade == false){
      
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(PositionSelectByTicket(tradeTicketBuy) == false && isOpenPositionInDay == false){
            // Abriremos compra porque no hay operacion abierta, llego señal y no hay orden de cerrar
            Print("ABRO COMPRA. No hay operacion abierta, llego señal y no hay orden de cerrar");
            
            // First set StopLoss Price
            //double lotSize = CalculateLotSize(_Symbol, amountToRiskBuy, slPrice);
            double lotSize = NormalizeDouble(amountToRiskBuy / slPips, decimalDigits);
            
            double newSL = slPrice - amountToAddToTPSL;
            double newTP = tpPrice + amountToAddToTPSL;
   
            trade.Buy(lotSize, _Symbol, currentPrice, newSL, newTP, "[BUY OPENED] XAUUSD Strategy London");
            tradeTicketBuy = trade.ResultOrder();
            
            isOpenPositionInDay = true;
            
            if(PositionSelectByTicket(tradeTicketBuy)) {
                openPriceReal = PositionGetDouble(POSITION_PRICE_OPEN);
                Print("Precio de apertura de la operación: ", openPriceReal);
            }
            
            double slReal = PositionGetDouble(POSITION_SL);
            double tpReal = PositionGetDouble(POSITION_TP);
            
            string telegramMessage = StringFormat(
                                 "[COMPRA ACTIVADA EN CUENTA %s] Precio Apertura: %s",
                                 accountStr,
                                 DoubleToString(openPriceReal));
   
            Print(telegramMessage);
   
            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);  
         } else {
            // Hay operacion abierta pero aun no hay señal de cierre, verificamos si ponemos BE
            if(set_be == true && alreadyInBreakEvenBuy == false) {
               trade.PositionModify(tradeTicketBuy, openPriceReal, tpPrice);
               alreadyInBreakEvenBuy = true;
               string telegramMessage = StringFormat("Movido SL a BreakEven en cuenta %s", accountStr);
               sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
            }
         }

      } else if (signal_type == "sell" && close_trade == false){

         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         Print("PositionSelectByTicket(tradeTicketSell): ", PositionSelectByTicket(tradeTicketSell));
         Print("isOpenPositionInDay: ", isOpenPositionInDay);
         
         if(PositionSelectByTicket(tradeTicketSell) == false && isOpenPositionInDay == false){
            // Abriremos compra porque no hay operacion abierta, llego señal y no hay orden de cerrar
            Print("ABRO VENTA. No hay operacion abierta, llego señal y no hay orden de cerrar");
            //double lotSize = CalculateLotSize(_Symbol, amountToRiskSell, slPrice);
            double lotSize = NormalizeDouble(amountToRiskSell / slPips, decimalDigits);
            double newSL = slPrice + amountToAddToTPSL;
            double newTP = tpPrice - amountToAddToTPSL;
            
            trade.Sell(lotSize, _Symbol, currentPrice, newSL, newTP, "[SELL OPENED] XAUUSD Strategy London");
            tradeTicketSell = trade.ResultOrder();
            
            isOpenPositionInDay = true;
            
            double slReal = PositionGetDouble(POSITION_SL);
            double tpReal = PositionGetDouble(POSITION_TP);
            
            if(PositionSelectByTicket(tradeTicketSell)) {
                openPriceReal = PositionGetDouble(POSITION_PRICE_OPEN);
                Print("Precio de apertura de la operación: ", openPriceReal);
            }
            
            string telegramMessage = StringFormat(
                                 "[VENTA ACTIVADA EN CUENTA %s] Precio Apertura: %s",
                                 accountStr,
                                 DoubleToString(openPriceReal));
   
            Print(telegramMessage);
   
            sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
         } else {
            // Hay operacion abierta pero aun no hay señal de cierre, verificamos si ponemos BE
            if(set_be == true && alreadyInBreakEvenSell == false) {
               trade.PositionModify(tradeTicketSell, openPriceReal, tpPrice);
               alreadyInBreakEvenBuy = true;
               string telegramMessage = StringFormat("Movido SL a BreakEven en cuenta %s", accountStr);
               sendTelegramMessage(telegramMessage, telegramChatID, telegramBotToken);
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
   string remainUrl = StringFormat("access-validation/%s/%s/tradingview_alert_bot_enabled/", userCode, accountNumber);

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
double CalculateLotSize(string symbol, double riskAmount, double slPrice)
  {
      double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
      double lotSize = 0.0;
      double symbol_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
      Print("slPrice: ", slPrice);
      Print("symbol_bid: ", symbol_bid);
      Print("pipValue: ", pipValue);
      lotSize = riskAmount / (MathAbs(symbol_bid - slPrice) / pointSize);
      Print("lotsize con slprice: ", lotSize);

   
      // Devolver el tamaño del lote
      int digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      
      return NormalizeDouble(lotSize, 2);
  }