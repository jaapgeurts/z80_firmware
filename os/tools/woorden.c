#include "sea80.h"

/****************************************************
Practicing typing words
 ****************************************************/
#define MAX_WORDS 201

char const * const words[MAX_WORDS] =  {
"stroop","half","brengen","lucht","bedankt",
"spreuk","kalf","wringen","nicht","pink",
"strop","wolf","zanger","specht","danken",
"straft","berg","verrassing","tachtig","vinken",
"arts","zwerm","uitbreiding","bericht","vonk",
"films","worm","tangen","verwachten","stinkt",
"stampt","werp","triangel","kachel","bonken",
"zwerft","hoorn","meng","zich","denk",
"tjilpt","kern","kringen","knechten","jonkvrouw"
"zwermt","hulp","koning","nachtegaal","klank",
"bericht","kabouters","pienter","amusant",
"heb","beneden","kleuren","bevestigen","patat",
"web","bezocht","getuige","artikel","patroon",
"drab","gemengd","buitenlands","asfalt","gazon",
"krab","geschikt","eenvoudig","uitzondering","kaneel",
"slab","gesteente","vernietigen","waarde","matras",
"vereist","rijkelijk","sponsor","tapijt",
"verroest","wijzen","optimaal","salade",
"verhongeren","stiekem","morgen","kanon",
"rib","meteen","trouwen","dolfijn","fazant",
"spatie","compliment","praktisch","aardbei","ravijn",
"vakantie","code","gigantisch","afscheid","tijger",
"presentatie","carnaval","kritisch","allebei","tijdens",
"traditie","toeristisch","arbeid","vijl",
"operatie","coltrui","elektrisch","feit","wijken",
"portie","camara","allergisch","fontein","rijpen",
"traktatie","categorie","medisch","weigeren","schatrijk",
"optie","cola","komisch","scheikunde","slijpen",
"droogste","bosbouw",
"spannendste","kinderboerderij",
"breedte","handdoek",
"grootte","fietsketting",
"wijdte","draaideur",
"heerlijkste","colafles",
"stoutste","koperblazers",
"zwaarste","landbouw",
"scherpste","achttien",
"eergisteren","duwt","draai","geeuw","honderd",
"meervoud","sluw","fraai","meeuw","kleed",
"veertien","schuw","dooi","kieuw","wreed",
"kantoor","uw","prooi","opnieuw","tand",
"voorwaarde","zenuw","loei","eeuwen","uitstekend",
"kleurt","waarschuw","knoei","leeuwinnen","aanwinst",
"scheurt","ruw","ronddraaien","barst",
"deel","zwaluw","vlaaien","meeuwen","beest",
"geel","zenuwachtig","gooien","nieuwer","tekort",
"momenteel","afschuw","loeien","sneeuwt","sprint", NULL
};


char buf[64];
unsigned char index;


void main() {

  srand(); // seed random with the r register

  println("Woorden typen. Type 'stop' om te stoppen.");

  index = (unsigned char)(rand() % MAX_WORDS);

  while(1) {

      println(words[index]);
      
      readline(buf,64);
      if (strcmp(buf,"stop") == 0) {
        println("Tot ziens");
        return;
      }

      if (strcmp(buf,words[index]) == 0) {
        println(" \x02 Heel goed!");
        index = rand() % MAX_WORDS;
      } else {
        println(" Jammer. Probeer het nog eens");
      }
      printline();
  }

}