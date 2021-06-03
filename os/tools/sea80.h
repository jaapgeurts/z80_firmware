#ifndef _SEA80_H
#define _SEA80_H

typedef unsigned char uint8_t; 

/* This header defines all Z80 Rom routines */

char getc();
void putc(char c);
void print(char* str);
void println();
void readline(char* str, uint8_t maxlen);
uint8_t strlen(char* str);

#endif