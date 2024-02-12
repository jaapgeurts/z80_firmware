#include "sea80.h"

/*
 * The formula is as described in the datasheet. The master clock is divided by 16, and divided by the tone period register value to get the tone frequency.

Thus, to calculate the tone period value from the frequency you want, 440 Hz is calculated as follows : (1,843,200 MHz / 16) / 440 Hz = 284 in decimal, or 0x011C in hex.
*/

int main()
{
    // a tone = 261 = 440hz
    // set tone
    io_output(PSG_COARSEA,IO_PSG_REG);
    io_output(0x02,IO_PSG_DATA);
    io_output(PSG_FINEA,IO_PSG_REG);
    io_output(0x61,IO_PSG_DATA);

    // set volume
    io_output(PSG_AMPLA,IO_PSG_REG);
    io_output(0x08,IO_PSG_DATA);

    // enable
    io_output(PSG_ENABLE, IO_PSG_REG);
    // active low
    io_output(0b10111110, IO_PSG_DATA);
}
