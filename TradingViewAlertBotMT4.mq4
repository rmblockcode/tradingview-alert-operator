//+------------------------------------------------------------------+
//|                                       TradingViewAlertBotMT4.mq4 |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input string signalUrl = "https://tradingview-alert-operator.onrender.com"; // No editar al menos que sea indicado
input string userCode = "joedoe"; // Código de usuario (Solicitar)

bool isOpenPositionInDay = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
    getSignal();
//---
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
   
  }
//+------------------------------------------------------------------+

void getSignal() {
   string cookie=NULL;
   string headers;
   string data; // En MQL4, posData debe ser un string vacío para GET
   char result[];
   char post[];
   string resultMessage;
   int timeout = 5000;
   int response;

   if (!isOpenPositionInDay) {
      string requestURL = StringFormat("%s/tradingview-alert/signal/%s/", signalUrl, userCode);
      response = WebRequest("GET",requestURL,cookie,NULL,timeout,post,0,result,headers);

      if(response > 0) {
         resultMessage = CharArrayToString(result);
         // Procesamiento simplificado de la respuesta
         // MQL4 no soporta directamente JSON, por lo que se necesitaría un método alternativo
         Print("Respuesta: ", resultMessage);

         // Aquí se asume una lógica simplificada basada en la respuesta como texto plano
         isOpenPositionInDay = true;
      } else {
         Print("Error en la solicitud WebRequest. Código de error: ", GetLastError());
      }
   }
}
