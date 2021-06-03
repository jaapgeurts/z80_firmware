#include "sea80.h"


void print(char* s) {
    while(*s != 0)
      putc(*s++);
}

void println() {
    putc(13);
    putc(10);
}

void readline(char* str, uint8_t maxlen) {
  uint8_t i=0;
  char c = getc();
  while(c != '\r') {
    putc(c);
    str[i++] = c;
    c = getc();
  }
  str[i] = 0;
}

uint8_t strlen(char* str) {
    uint8_t i=0;
    while (*str++ != 0)
      i++;
    return i;
}

char getc() {
    __asm
getKeyWait:
    rst  0x08
    jr   z, getKeyWait
    ld   l,a
    __endasm;
}

void putc(char c) {
    __asm
    ld   iy,#2
    add  iy,sp ; skip the return value
    
    ld   a,(iy)
    rst  0x10
    __endasm;
}