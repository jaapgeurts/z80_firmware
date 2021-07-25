#ifndef _SEA80_H
#define _SEA80_H

typedef unsigned char uint8_t; 
typedef unsigned short uint16_t; 

#define NULL ((void*)0)

/* This header defines all Z80 Rom routines */

char getc();
void putc(char c);
void print(const char* str);
void println(const char* str);
void printline();
void readline(char* str, uint8_t maxlen);
void clearscreen();
uint8_t strlen(const char* str);
int strcmp(const char *s1, const char *s2);
void srand();
uint16_t rand();
int atoi(const char*s);
void itoa(int n, char* s);

#endif