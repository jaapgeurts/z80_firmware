#include "sea80.h"

uint8_t a,b,c;

char buf[256];

void main() {

    print("Tafels oefenen\r\n");
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
            c = atoi(buf);
            if (c != a*b)
                print(" Jammer. Probeer nog eens.\r\n");
        }
        while (c != a * b);
        print(" Heel goed!\r\n");
    }

}