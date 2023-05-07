/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                                                 Multi Serial Data Logger AvionicsDuino V 1.0 
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  MIT License (MIT). MultiSerialDataLogger_AvionicsDuino is free software.
  
  Copyright (c) 2023 AvionicsDuino - benjamin.fremond@avionicsduino.com
  https://avionicsduino.com/index.php/en/flight-data-recorder/
  
  Permission is hereby granted, free of charge, to any person obtaining a copy 
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights 
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
  of the Software, and to permit persons to whom the Software is furnished to do so, 
  subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in 
  all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  
 *****************************************************************************************************************************/ 

import processing.serial.*;
import java.io.File;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.io.IOException; 

DateFormat formatter = new SimpleDateFormat("HH:mm:ss.SSS"); // format utilisé pour l'horodatage
Calendar calendar = Calendar.getInstance();

 class ExeCommande // Cette nouvelle classe sera utilisée pour exécuter une commande externe (dans la fenêtre "invite de commande" de Windows) pour le réglage de l'heure du système. Valable pour Windows seulement.
                   // (d'après https://codes-sources.commentcamarche.net/source/54094-exemple-d-utilisation-de-la-classe-runtime)
 {
   ExeCommande (){ } // Constructeur vide
   void reglageHeure(String chaine) // la variable chaine doit contenir l'heure au format HH:MM:SS
   {
    String commande=""; 
    int exitValue=0;       
    commande = chaine;              
    Runtime runtime = Runtime.getRuntime();      
    try 
    {
      Process process = runtime.exec("cmd.exe /c Time " + commande); // Création et lancement de processus qui exécute reglageHeure
      exitValue=process.waitFor(); // On enregistre le code retour
    }
    catch (IOException e) { }
    catch (InterruptedException e) { } 
   }
 } 
 ExeCommande execute = new ExeCommande(); // Création de l'objet "execute", de classe ExeCommande
 

class PortCom extends Serial // création d'une nouvelle classe héritée de la classe Serial, pour rajouter le flag "toRecord" qui indique si le flux entrant du port concerné doit être enregistré ou non
{
  boolean toRecord;
  PortCom (PApplet parent, String portName, int baudRate, boolean trcd)
  {
    super (parent, portName, baudRate);
    toRecord = trcd;
  }  
}
PortCom[] myPorts = new PortCom[6];  // Crée un tableau pour 6 objets de la classe PortCom. On voit large, il n'y aura probablement jamais autant de ports COM à exploiter...

PrintWriter[] output = new PrintWriter[6];  // Création d'un tableau pouvant contenir 6 objets PrintWriter, pour l'enregistrement des données reçues dans des fichiers. Avec 6 fichiers, on prévoit large...

String[] portsDispos; // Crée un tableau de chaines qui contiendra les noms de tous les ports COM disponibles
int nbPortsDispos = 0; // Cette variable contiendra le nombre de ports COM disponibles

float xbss = 300, ybss = 0, wbss = 200, hbss = 30; // Coordonnées du cadre du bouton START/STOP (bss)
float xl = 20, yl=40, wl = 60, incl = 20; // Cadre de la liste (l) des ports disponibles. la variable incl correspond à la hauteur (l'incrément) des cases
float xcp = 360, ycp= 182, wcp = 60, hcp = 15; // cadre pour indiquer le nom du port dont on affiche un aperçu du flux

boolean recording = false; // Flag qui indique si l'enregistrement est commencé ou non

String chemin = "D:\\Dropbox\\LATTEPANDA\\DataLogging\\"; // Cette chaîne et les 2 suivantes sont utilisées pour la définition du chemin et des noms de fichiers pour les enregistrements
String nomFile = "port_";
String extension = ".txt";
String horodatFile = "";

boolean timeSet=false; // Ce flag indique si l'heure a été réglée par le GNSS

int numPortGps=-1; // numéro d'ordre du port auquel est connecté le GPS. Pour COM4, par exemple, ce numéro sera 0 si COM4 est le premier port détecté
boolean gpsFound = false; // flag qui indique si un GPS a été trouvé, ce qui sera le cas dès qu'un caractère '$' aura été détecté sur un port série quelconque
String trameNMEA=""; // une chaine où on stockera une trame NMEA
String identTrameNMEA=""; // l'identifiant de la trame : GGA, RMC...etc.

int angleRot=0;

PImage sablier;
PImage enregistre;
PImage gps;


void setup()  
{
 size(600,500);
 stroke(0);
 background(255);
 fill(200);
 rect(xbss,ybss,wbss,hbss);
 textSize(25);
 fill(0);
 text ("ENREGISTRER",xbss+25,ybss+25);
 textSize(15);
 text ("Aperçu du flux du port ", 120,195);
 line (0,200,width,200);


sablier = loadImage("sablier.png");
enregistre = loadImage("enregistre.png");
gps = loadImage("gps.png");



 
portsDispos = (PortCom.list()); // Rempli le tableau de chaine portsDispos avec les noms de tous les ports COM disponibles
nbPortsDispos = (portsDispos.length);

text ("Ce PC dispose de " + nbPortsDispos +" ports série :",xl-10,yl-20); //
int n;
horodatFile = year() + "_"+ month() + "_"+ day() + "_" + hour() + "_"+ minute() + "_"+ second()+ "_"; 
for (n=0; n<nbPortsDispos; n++) // on affiche les nom de tous les ports com disponibles, et on les initialise. On crée également les fichiers d'enregistrement, tous ne serviront pas forcément
  {
   fill(0);
   text(PortCom.list()[n],xl+5,yl+incl*n); 
   noFill();
   rect(xl, yl-15+incl*n, wl,incl);
   myPorts[n] = new PortCom(this, PortCom.list()[n], 115200, false); // tous les ports disponibles sont initialisés à 115200 bauds et avec leur flag toRecord sur false
   myPorts[n].buffer(1); // la fonction serialEvent est déclenchée à chaque octet reçu
   output[n] = createWriter(chemin + horodatFile + nomFile + char(65+n) + extension); // Création des fichiers d'enregistrement
  }  
text ("Cliquez sur ceux que vous souhaitez ouvrir et enregistrer",xl-10,yl+incl*n); 

frameRate(30); // La boucle draw() ne fait rien d'autre que d'afficher des messages d'état du programme, une fréquence de 10 Hz est largement suffisante

for (int i=0; i<nbPortsDispos; i++) // On vide tous les buffers série juste avant de commencer le programme
                                         
     {
       myPorts[i].clear();
     }


imageMode(CENTER);  
}

void draw() 
{
  numPortGps=0; //. If you don't need a GPS, you can uncomment this line and the next one.
  timeSet = true;
  if(numPortGps > -1 && timeSet == false) // si un GPS/GNSS a été détecté mais que le fix n'est pas fait et donc l'heure n'est pas réglée
  {
    fill(170);
    rect (0,470,600,30);
    fill(50);
    textSize(13);
    text ("GPS/GNSS sur le port " + PortCom.list()[numPortGps] +", FIX et réglage de l'heure en cours. Veuillez patienter...",5,490);
    
    fill(200);
    rect(xbss,ybss,wbss,hbss);
    textSize(25);
    fill(180);
    text ("ENREGISTRER",xbss+25,ybss+25);
    iconeRotative(sablier,6);
  }
  if(numPortGps == -1) // si aucun GPS n'a   été détecté
  {
    fill(170);
    rect (0,470,600,30);
    fill(50);
    textSize(13);
    text ("Aucun GPS/GNSS détecté, veuillez fermer l'application et en connecter un.",5,490);
    
    fill(200);
    rect(xbss,ybss,wbss,hbss);
    textSize(25);
    fill(180);
    text ("ENREGISTRER",xbss+25,ybss+25);
    iconeRotative(gps,6);
  }
  if(numPortGps > -1 && timeSet == true) // si un GPS a bien été détecté, que son fix est fait et l'heure système réglée
  {
    if(recording==true) // et si l'enregistrement est en cours
    {
      fill(0);
      rect(xbss,ybss,wbss,hbss);
      textSize(25);
      fill(255);
      text ("     STOP",xbss+25,ybss+25);
      
      fill(170);
      rect (0,470,600,30);
      fill(50);
      textSize(13);
      text ("Enregistrement en cours.",5,490);
      iconeRotative(enregistre,6);
    }
    else // ou si l'enregistrement n'est pas encore commencé
    {
      fill(200);
      rect(xbss,ybss,wbss,hbss);
      textSize(25);
      fill(0);
      text ("ENREGISTRER",xbss+25,ybss+25);
      
      fill(170);
      rect (0,470,600,30);
      fill(50);
      textSize(13);
      text ("L'heure du système est réglée sur le GPS/GNSS. Les enregistrements peuvent commencer.",5,490);
      iconeRotative(enregistre,0);
    }
  }
  
}


void mouseReleased()
{
 if(mouseX>xbss && mouseX <xbss+wbss && mouseY>ybss && mouseY <ybss+hbss) // Si un clic a eu lieu sur le bouton START/STOP
  {
   if (recording == true) // si l'enregistrement est en cours, c'est qu'on veut l'arrêter et terminer le programme
   {     
     for (int n=0; n<nbPortsDispos; n++) 
     {
       output[n].flush();  // Ecrit les données restantes dans le fichier
       output[n].close();  // Clôture le fichier 
       if(myPorts[n].toRecord==false) // Si le port concerné n'était pas selectionné pour un enregistrement, on supprime le fichier qui avait été créé dans le setup
       {
         File f = new File(chemin + horodatFile + nomFile + char(65+n) + extension);
         if (f.exists()) f.delete();
       }
       
     }  
     exit();           // Arrête le programme
   }
   else // si l'enregistrement n'est pas en cours, c'est qu'on veut le débuter
   {
     if(timeSet==true) // mais on ne peut le débuter que si l'heure a été réglée sur le GPS
     {
         recording=true;
         for (int n=0; n<nbPortsDispos; n++) // Important +++ : vider TOUS les buffers série juste avant de commencer les enregistrements. Sinon, des buffers pleins au début vont entraîner de gros retards des flux série sur l'horodatage.
                                             // En effet, les données les plus anciennes des buffers sont traitées en premier.
         {
           myPorts[n].clear();
         }
     }    
   }  
  }
  
  if(mouseX>xl && mouseX <xl+wl && mouseY>yl-15 && mouseY <yl-15+incl*nbPortsDispos) // Si un clic a eu lieu dans la liste des ports, c'est qu'on souhaite sélectionner un port pour l'enregistrement
  {
    int n = int( (mouseY-(yl-15))/incl); // n contient le numéro de la case cliquée
    fill(0);
    if (myPorts[n].toRecord==false) // si le port cliqué n'est pas actuellement sélectionné pour l'enregistrement, on le sélectionne pour l'enregistrement, et on affiche sa case en blanc sur fond noir
    {
      myPorts[n].toRecord=true;
      fill(0);
      rect (xl, yl-15+incl*n, wl,incl);
      fill(255);
      textSize(15);
      text(PortCom.list()[n],xl+5,yl+incl*n);
      // et on prévisualise quelques caractères (maximum max) qui arrivent sur ce port, s'il y en a
      int max=150, i=0;
      String previsual = ""; // la chaine qui va contenir max caractères du flux de données du port cliqué
      while (myPorts[n].available()>0 && i<= max)
      {
        previsual = previsual + char(myPorts[n].read());
        i++;
      } 
      fill (255);
      rect(0,200,width, 270); // on efface d'éventuelles données prévisualisées auparavant avant d'afficher les nouvelles
      fill(0);
      textSize(12);
      text(previsual, 10,215); // et on affiche les données
      fill(255);
      rect (xcp,ycp,wcp,hcp); // on efface l'eventuel précédent nom de port prévisualisé
      textSize(15);
      fill(0);
      text(PortCom.list()[n], xcp+5,ycp+13); // et on affiche le nom du port prévisualisé
    }
    else // si par contre le port cliqué est déjà sélectionné pour l'enregistrement, on le désélectionne pour l'enregistrement, et on affiche sa case en caractères noirs sur fond blanc
    {
      myPorts[n].toRecord=false;
      fill(255);
      rect (xl, yl-15+incl*n, wl,incl);
      fill(0);
      textSize(15);
      text(PortCom.list()[n],xl+5,yl+incl*n);      
    }  
  }  
}

void serialEvent(PortCom quelPort) // cette fonction est appellée à chaque fois qu'un nouvel octet de données est disponible sur un port série quelconque, elle indique quel port a généré cet évènement
{ 
// On commence par déterminer le port COM responsable de l'interruption 
  int numeroPort = -1; // variable pour contenir le numéro du port qui a déclenché l'évènement
  int octetEntrant = -1; // variable pour contenir un octet lu sur un port série
    for (int n = 0; n < myPorts.length; n++) // On parcourt la liste des ports ouverts pour trouver le numéro de celui qui a généré l'evènement
    {
      if (quelPort == myPorts[n]) {numeroPort = n; break;}
    }
  

// Premier cas : l'enregistrement est en cours, l'heure du système a été réglée grâce au GPS/GNSS  
  if (recording == true && timeSet==true) // on exécute cette partie (enregistrement dans un fichier) uniquement lorsque l'enregistrement est lancé et l'heure réglée
  {
    octetEntrant = quelPort.read();  // on lit le nouvel octet sur ce port
    
    if(myPorts[numeroPort].toRecord==true) // on enregistre ce port uniquement si son flag toRecord est sur true
    {
      output[numeroPort].print(char(octetEntrant));
      
      if (octetEntrant == 10) // si on vient de passer à la ligne, on commence la ligne suivante par un horodatage selon l'heure système du PC
      {
       long now = System.currentTimeMillis();
       calendar.setTimeInMillis(now);
       //output[numeroPort].print(formatter.format(calendar.getTime()) + ";"); //. If you don't need timestamping, you can comment this line
      } 
    }  
  }

// Deuxième cas, l'heure n'a pas encore été réglée  
  if (timeSet==false) // Si l'heure système n'a pas encore été réglée sur l'heure GPS/GNSS
  {
    octetEntrant = quelPort.read();  // on lit le nouvel octet sur ce port
    if(char(octetEntrant)=='$') // On est au début d'une nouvelle trame NMEA (pour que ce datalogger fonctionne, on doit être certain qu'aucun autre périphérique que le GPS/GNSS n'envoie ce caractère $ sur un quelconque port COM
    {
      if (numPortGps == -1) // Si cette condition est vérifiée, c'est que l'index du port COM du GPS/GNSS n'était pas encore connu
      {
        numPortGps = numeroPort; // mais on connaît maintenant l'index du port COM du GPS, cet index est stocké dans la variable globale numPortGps 
        println ("GPS trouvé sur le port " + PortCom.list()[numPortGps]);
      }
      
      trameNMEA = ""; // On part avec une chaine vide
      
      println (trameNMEA, "début trame");
    }
    
    if (numeroPort == numPortGps) // si le caratère entrant vient du GPS...
    {
      trameNMEA = trameNMEA + char(octetEntrant); // on l'ajoute à la chaine "trameNMEA". Tous les octets qui vont désormais arriver sur le port du GPS/GNSS seront ajoutés à cette chaine, jusqu'à trouver le caractère '*'
      println (trameNMEA);
      
      if (octetEntrant==10 && trameNMEA.substring(3,6).equals("GGA")) // si on a atteint la fin d'une trame NMEA GGA, on peut la décoder, puis vider la chaine et remettre l'index à zéro
      {
        println("------------------------------------------------------------------------");
        String[] champ = split(trameNMEA,","); // on découpe la trame NMEA en ses champs constitutifs séparés par des virgules
        println(champ[6]);
        if (champ[6].equals("0")) // alors le fix n'est pas encore réalisé, l'heure de la trame NMEA, si elle existe déjà, n'est pas valable. On doit donc continuer à scruter les trames jusqu'au fix
        {
          trameNMEA = ""; //on repart donc avec une chaine vide
          
        }
        else // si le 6ème champ de la trame GGA (FIX) est différent de zéro, le fix est fait, on peut alors exploiter l'heure GPS/GNSS, à condition que la trame soit émise avec une seconde entière, sinon on continue à attendre la bonne trame
        {
          println("==============================", trameNMEA.substring(14,16));
          if (trameNMEA.substring(14,16).equals("00")) // si la seconde est entière, c'est bon, on règle l'heure du PC
          {
            timeSet = true;
            String HH = trameNMEA.substring(7,9);
            String MM = trameNMEA.substring(9,11);
            String SS = trameNMEA.substring(11,13);
            execute.reglageHeure(HH+":"+MM+":"+SS);
          }
          else // si la seconde n'est pas entière, on continue à scruter
          {
            trameNMEA = "";
            
          }
        }
      }  
    }  
  }  
  
}

void iconeRotative(PImage icone, int incRot)
{
  noStroke();
  fill(255);
  ellipse(550,430,63,63);
  
  pushMatrix(); 
  translate(550, 430);
  rotate(radians(angleRot)); 
  image(icone, 0, 0);
  popMatrix(); 
  angleRot += incRot;
  if (angleRot >=360) angleRot=0;
  stroke(0);
}
