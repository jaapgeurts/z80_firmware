#include "sea80.h"

/* see: https://gist.github.com/Konamiman/af5645b9998c802753023cf1be8a2970

Assembler code must preserve the value of IX, all other registers can be used freely.

    Functions that return char: in the L register
    Functions that return int or a pointer: in the HL registers
    Functions that return long: in the DEHL registers

*/

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
  while(c != '\r' && i < maxlen) {
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

int atoi(char* s) {
    int acum = 0;
    int factor = 1;
    
    if(*s == '-') {
        factor = -1;
        s++;
    }
    
    while((*s >= '0')&&(*s <= '9')) {
      acum = acum * 10;
      acum = acum + (*s - 48);
      s++;
    }
    return (factor * acum);
}

static void reverse( char* s )
{
  int i, j ;
  char c ;

  for ( i = 0, j = strlen(s)-1 ; i < j ; i++, j-- )
  {
    c = s[i] ;
    s[i] = s[j] ;
    s[j] = c ;
  }
}

/* itoa:  convert n to characters in s */
void itoa( int n, char* s )
{
  int i, sign ;

  if ( (sign = n) < 0 )  /* record sign */
  {
    n = -n;          /* make n positive */
  }

  i = 0;
  do
  {       /* generate digits in reverse order */
    s[i++] = n % 10 + '0';   /* get next digit */
  } while ((n /= 10) > 0) ;     /* delete it */

  if (sign < 0 )
  {
    s[i++] = '-';
  }

  s[i] = '\0';

  reverse( s ) ;
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

/*
 Returns a random number 0 <= r <= 255
 */
uint8_t rand() {
    __asm
    ld  a,r
    ld  l,a
    __endasm;
}