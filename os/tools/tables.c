#include "sea80.h"

uint8_t a,b,c;

char buf[256];

void main() {

    print("Tafels oefenen. (Typ 'stop' om te stoppen)\r\n");
    print("Reken uit:\r\n");

    srand(); // seed random with the r register

    for(;;) {
        a = rand();
        a = a % 9 + 1;
        b = rand();
        b = b % 9 + 1;
        do {
            itoa(a,buf);
            print(buf);
            print(" x ");
            itoa(b,buf);
            print(buf);
            print(" = ");
            readline(buf,255);
            if (strcmp(buf,"stop") == 0) {
                print(" Tot ziens\r\n");
                return;
            }
            c = atoi(buf);
            if (c != a*b)
                print(" Jammer. Probeer nog eens.\r\n");
        }
        while (c != a * b);
        print(" \x02 Heel goed!\r\n");
    }

}