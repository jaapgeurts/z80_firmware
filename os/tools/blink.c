#include "sea80.h"

int main()
{

    while (1) {
        io_output(PSG_PORTB,IO_PSG_REG);
        io_output(0x0E,IO_PSG_DATA);
        delay(1000);
        io_output(PSG_PORTB,IO_PSG_REG);
        io_output(0x00,IO_PSG_DATA);
        delay(1000);
    }
}
