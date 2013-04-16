

//--- input parameters
extern int casVstup = 0;    //cas vstupu na trh
extern int casVystup = 22;  //cas odchodu z trhu
extern double lots = 5.0;   //velikost lotu

extern int lengthMA1 = 12;  //doba pro kterou se pocita klouzavy prumer
extern int lengthMA2 = 34;
extern int takeProfitIncrement = 10; // O kolik se pousova profit
extern int currentCloseIncrement = 20; // O kolik se posouva close
extern int stopLossInitialValue = 30; // Puvodni odchylka stopLoss
extern int takeProfitInitialValue = 40; // Puvodni odchylka takeProfit


int stav = 0;

//prikazy pro prodej/nakup
int ticket1 = 0;
int ticket2 = 0;

//prom. slouzici k optimalizaci ztraty a zvyseni zisku
double takeProfit = 0.0;
double stopLoss = 0.0;
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+

//kontrola protnuti 2 klouzavych prumeru. Jestlize protnuto, vraci se true, jinak false.
bool intersect(double ma1, double ma2)
{
    bool result = false;
    double ma1r = NormalizeDouble(ma1,5);
    double ma2r = NormalizeDouble(ma2,5);
    
    if (ma1r == ma2r)    
        result = true;
    
    return(result);    
}

//zjisteni skonu klouzavych prumeru, pokud oba jsou rostouci vraci funkce 1, oba klesajici vrati -1, jinak vraci 0
//zjisteni sklonu podle poslednich 4 hodnot krivky, pokud kazdy nasledujici bod je vetsi nebo roven tomu poredchozimu, bere se krivka jako rostouci
int getLeanMA()
{
    int result = 0;
    double ma1val0 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,0);
    double ma1val1 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,2);
    double ma1val2 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,4);
    double ma1val3 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,6);
    
    double ma2val0 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,0);
    double ma2val1 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,2);
    double ma2val2 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,4);
    double ma2val3 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,6);
    
    if (ma1val0 >= ma1val1 && ma1val1 >= ma1val2 && ma1val2 >= ma1val3 &&
        ma2val0 >= ma2val1 && ma2val1 >= ma2val2 && ma2val2 >= ma2val3)
        result = 1;
    else if (ma1val0 <= ma1val1 && ma1val1 <= ma1val2 && ma1val2 <= ma1val3 &&
             ma2val0 <= ma2val1 && ma2val1 <= ma2val2 && ma2val2 <= ma2val3)
        result = -1;    
    
    return(result);
}

int start()
{
    int timeFrame = PERIOD_M1;
 
    //ziskani hodnot klouzavych prumeru pro aktualni hodnotu
    double ma1 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,0);  //MODE_EMA - exponencialni varianta vypoctu - vice kopiruje trzni cenu, pouzivanejsi
    double ma2 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,0);  // simple - jednoducha
     
// nasledujúce riadky by bolo fajn dat do inicializácie (ak to bude reálne možné)
  /* if(prom1 > prom2)
   {
      stav=1; //1
   }
   if(prom1 < prom2)
   {
      stav=2; //2
   }*/
   
// test casu vstupu a vystupu (len v určitých časových intervaloch a dňoch v týždni sa budú vykonávať transakcie (okrem rozbehnutej transakcie - na toto treba dať bacha; takisto aj na konci dňa)
    
   double currClose = iClose(Symbol(),timeFrame,0);

   switch(stav)
   {
      case 0:
         if(TimeHour(iTime(Symbol(),timeFrame,0)) >= casVstup)              //podminka pro cas vstupu tu muze byt, pokud bereme v uvahu optimalizaci obchodovani jen v urcitem case
         { // tu nebude vubec záležat na čase, len na pretnutí funkcií
            if(intersect(ma1,ma2))  //protnuti dvou klouzavych prumeru 
            {   
                //urceni sklonu klouzavych prumeru
                int c = getLeanMA();
            
                if (c == 1) //a je vzrustajici trend
                {
                    //provedeme nakup
                    ticket1 = OrderSend(Symbol(),OP_BUY,lots,Ask,3,0,0);
                    if(ticket1 < 0)
                    {
                        Print("OrderSend failed with error #",GetLastError());
                        return(0);
                    }
                    stopLoss = Bid - stopLossInitialValue * Point;    //nastaveni povolene ztraty o 15 bodu niz nez je prodejni cena
                    takeProfit = Bid + takeProfitInitialValue * Point;  //nastaveni pozadavek na cenu pro uzavreni (nastaveno o 15 bodu vic nez je prodejni cena)  //zde je prostor pro nejakou tu optimalizaci na kolik nastavit tuto hodnotu
                    stav=1;
                }
                else if (c == -1) //je klesajici trend
                {   //provedeme prodej
                    ticket2 = OrderSend(Symbol(),OP_SELL,lots,Bid,3,0,0);
                    if(ticket2 < 0)
                    {
                        Print("OrderSend failed with error #",GetLastError());
                        return(0);
                    }
                    stopLoss = Ask + stopLossInitialValue * Point;
                    takeProfit = Ask - takeProfitInitialValue * Point;  //zde je vhodne pouzit nejakou tu optimalizaci pro odhad takeprofit
                    stav = 2;
                }           
            }
         }
      break;
      
      case 1:  //test zda se jiz ma prodat nebo jeste ne           
         if(currClose < stopLoss)   //pokud cena klesla pod hranici stoploss Pozn.: tady je potreba se zamyslet pro ketrou z hodnot testovat jestli klesla pod hranici stoploss (iLow nebo iClose?)
         {  
            OrderClose(ticket1,lots,Bid,3);
            if(ticket1 < 0)
            {
                Print("OrderSend failed with error #",GetLastError());
                return(0);
            }
            stav=0;
         }
         else if (currClose > takeProfit) //pokud cena vzrostla nad takeprofit, prepocitani hodnot Pozn.: opet mozna debata pro kterou hodnotu je idealni testovat ze prekonala takeprofit
         {
            //cena vzrostla nad ocekavany zisk, neprodame hned, ale prenastavime hranice a zkusime, zda cena neporoste jeste vys
            stopLoss = takeProfit - takeProfitIncrement * Point;
            takeProfit = currClose + currentCloseIncrement * Point;
         }  
      break;
      
      case 2:   //test zda se jiz ma koupit nebo jeste ne   
         if(currClose > stopLoss) //cena vzrostla nad hranici ztraty -> prodavame
         {  
            OrderClose(ticket2,lots,Ask,3);
            if(ticket2 < 0)
            {
                Print("OrderSend failed with error #",GetLastError());
                return(0);
            }
            stav=0;
         }
         else if (currClose < takeProfit) //cena klesa pod stanoveny zisk, jeste neprodame a posuneme hranice prodeje
         {
            stopLoss = takeProfit + takeProfitIncrement *Point;
            takeProfit = currClose - currentCloseIncrement * Point;
         }  
      break;
      
   }
   
   return(0);
}
//+------------------------------------------------------------------+

