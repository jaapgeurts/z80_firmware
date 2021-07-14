#ifndef _SEA80_H
#define _SEA80_H

typedef unsigned char uint8_t; 

#define NULL ((void*)0)

/* This header defines all Z80 Rom routines */

char getc();
void putc(char c);
void print(char* str);
void println();
void readline(char* str, uint8_t maxlen);
uint8_t strlen(char* str);
int strcmp(const char *s1, const char *s2);
uint8_t rand();
int atoi(char*s);
void itoa(int n, char* s);

#endif