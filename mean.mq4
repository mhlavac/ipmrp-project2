/*
 *  Nazev: mean.mq4
 *  Datum: 18.4.2013
 *  Popis: 2. projekt do predmetu IpmrP. Skript slouzici pro automatizovane obchodovani na menovych trzich. 
 */
//--- input parameters
//casy vstupu a vystupu na nejvyznamnejsi trhy 1- japonska burza, 2 - americka, 3 - anglicka
extern int casVstup1 = 1;    //cas vstupu na trh
extern int casVystup1 = 3;   //cas odchodu z trhu
extern int casVstup2 = 10;    
extern int casVystup2 = 12; 
extern int casVstup3 = 14; 
extern int casVystup3 = 17; 

extern double lots = 1.0;   //velikost lotu

extern int lengthMA1 = 12;  //doba pro kterou se pocita klouzavy prumer
extern int lengthMA2 = 34;
extern int stopLossIncrement = 30; // O kolik se pousova ztrata
extern int takeProfitIncrement = 45; // O kolik se posouva profit
extern int stopLossInitialValue = 55; // Puvodni odchylka stopLoss
extern int takeProfitInitialValue = 5; // Puvodni odchylka takeProfit

int stav = 0;

//prikazy pro prodej/nakup
int ticket1 = 0;
int ticket2 = 0;

//prom. slouzici k optimalizaci ztraty a zvyseni zisku
double takeProfit = 0.0;
double stopLoss = 0.0;
//+------------------------------------------------------------------+

/*
 * intersect: kontrola protnuti 2 klouzavych prumeru. 
 * Jestlize protnuto, vraci se true, jinak false.
 * @param ma1, ma2 - klouzave prumery, pro ktere je 
 * testovano protnuti.
 */
bool intersect(double ma1, double ma2)
{
    bool result = false;
    /* hodnoty jsou zaokrouhleny na 4 des. mista, aby se indikivalo
       protnuti i pro velmi blizke priblizeni krivek */
    double ma1r = NormalizeDouble(ma1,4);
    double ma2r = NormalizeDouble(ma2,4);
    
    if (ma1r == ma2r)    
        result = true;
    
    return(result);    
}

/* getLeanMA: zjisteni skonu klouzavych prumeru, pokud oba jsou 
 * rostouci, vraci funkce 1, oba klesajici vrati -1, jinak vraci 0.
 * Zjisteni sklonu podle poslednich x hodnot krivky, pokud kazdy 
 * nasledujici bod je vetsi nebo roven tomu poredchozimu, bere 
 * se krivka jako rostouci.
 */
int getLeanMA()
{
    int result = 0;
    double ma1val0 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,0);
    double ma1val1 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,2);
    double ma1val2 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,6);
    double ma1val3 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,10);
    
    double ma2val0 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,0);
    double ma2val1 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,2);
    double ma2val2 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,6);
    double ma2val3 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,10);
    
    if (ma1val0 >= ma1val1 && ma1val1 >= ma1val2 && ma1val2 >= ma1val3 &&
        ma2val0 >= ma2val1 && ma2val1 >= ma2val2 && ma2val2 >= ma2val3)
        result = 1;
    else if (ma1val0 <= ma1val1 && ma1val1 <= ma1val2 && ma1val2 <= ma1val3 &&
             ma2val0 <= ma2val1 && ma2val1 <= ma2val2 && ma2val2 <= ma2val3)
        result = -1;    
    
    return(result);
}

/*
 * performTrade: test, zda je doba vhodna pro
 * obchodovani na burze. V uvahu jsou brany
 * casy tri nejvyznamnejsich trhu (Jap., Am., Angl.)
 */
bool performTrade()
{
    int timeFrame = PERIOD_M1;
    bool result = false;
    
    int time = TimeHour(iTime(Symbol(),timeFrame,0));
 
    /* pokud je aktualni cas v rozmezi hodin dane burzy,
       vraci funkce hodnotu true */  
    if((time >= casVstup1 && time <= casVystup1) ||
       (time >= casVstup2 && time <= casVystup2) ||
       (time >= casVstup3 && time <= casVystup3))
    {
        result = true;
    }
    
    return(result);
}

/*
 * start: hlavni funkce skriptu spoustena pri kazdem
 * pohybu kurzu.
 */
int start()
{
   int timeFrame = PERIOD_M1;    
   double currClose = iClose(Symbol(),timeFrame,0); //zjisteni aktualni hodnoty close
   
   //ziskani hodnot klouzavych prumeru pro aktualni hodnotu
   double ma1 = iMA(NULL,0,lengthMA1,0,MODE_SMA,PRICE_MEDIAN,0);  //MODE_EMA - exponencialni varianta vypoctu - vice kopiruje trzni cenu, pouzivanejsi
   double ma2 = iMA(NULL,0,lengthMA2,0,MODE_EMA,PRICE_MEDIAN,0);  // simple - jednoducha varianta vypoctu kl. prum.

   switch(stav)
   {
      case 0:    
         if(performTrade() == true)              //pokud je cas vhodny pro obchodovani 
         {
            if(intersect(ma1,ma2))  //protnuti dvou klouzavych prumeru 
            {                                   
                //urceni sklonu klouzavych prumeru
                int c = getLeanMA();
            
                if (c == 1) //je vzrustajici trend
                {
                    //provedeme nakup
                    ticket1 = OrderSend(Symbol(),OP_BUY,lots,Ask,3,0,0);
                    if(ticket1 < 0)
                    {
                        Print("OrderSend failed with error #",GetLastError());
                        return(0);
                    }
                    stopLoss = Ask - stopLossInitialValue * Point;      //nastaveni povolene ztraty o x bodu niz nez je nakupni cena
                    takeProfit = Ask + takeProfitInitialValue * Point;  //nastaveny pozadavek na cenu pro uzavreni
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
                    stopLoss = Bid + stopLossInitialValue * Point;
                    takeProfit = Bid - takeProfitInitialValue * Point;
                    stav = 2;                 
                }           
            }
         }
      break;
      
      case 1:  //test zda se jiz ma prodat nebo jeste ne        
         if(currClose < stopLoss)   //pokud cena klesla pod hranici stoploss
         {  
            OrderClose(ticket1,lots,Bid,3);
            if(ticket1 < 0)
            {
                Print("OrderSend failed with error #",GetLastError());
                return(0);
            }    
            stav=0;
         }
         else if (currClose > takeProfit) //pokud cena vzrostla nad takeprofit, prepocitani hodnot
         {
            //cena vzrostla nad ocekavany zisk, neprodame hned, ale prenastavime hranice a zkusime, zda cena neporoste jeste vice
            stopLoss = takeProfit - stopLossIncrement * Point;
            takeProfit = currClose + takeProfitIncrement * Point;
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
            stopLoss = takeProfit + stopLossIncrement *Point;
            takeProfit = currClose - takeProfitIncrement * Point;
         }  
      break;
      
   }
   
   return(0);
}
//+------------------------------------------------------------------+


