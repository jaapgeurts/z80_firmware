#ifndef _SEA80_H
#define _SEA80_H

#define PSG_FINEA 0
#define PSG_COARSEA 1
#define PSG_AMPLA 8

#define PSG_FINEB 2
#define PSG_COARSEB 3
#define PSG_AMPLB 9

#define PSG_FINEC 4
#define PSG_COARSEC 5
#define PSG_AMPLC 10

#define PSG_ENABLE 7
#define PSG_PORTA 14
#define PSG_PORTB 15

#define IO_PSG_REG 0x80
#define IO_PSG_DATA 0x81

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;

#define LOW 0
#define HIGH 1

#define NULL ((void*)0)

#define UNUSED(x) x

/* This header defines all Z80 Rom routines */

/* ROM functions */
char getc() __sdcccall(0);
void putc(char c) __sdcccall(0);
void print(const char* str);
void println(const char* str);
void printline();
void readline(char* str, uint8_t maxlen);
void clearscreen() __sdcccall(0);
uint8_t strlen(const char* str);
int strcmp(const char* s1, const char* s2);

/* Convenience functions */
void srand() __sdcccall(0);
uint16_t rand()  __sdcccall(0);
int atoi(const char* s);
void itoa(int n, char* s);

void delay(uint16_t millis);

void io_output(uint8_t data, uint8_t port);
uint8_t io_input(uint8_t port);

// void digitalWrite(uint8_t port, uint8_t level);

#endif
