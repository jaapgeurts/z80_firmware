MEMORY {
    ROM1 : ORIGIN = 0x0000, LENGTH = 0x2000
    ROM2 : ORIGIN = 0x2000, LENGTH = 0x2000
    SYSRAM: ORIGIN = 0xf000, LENGTH = 0x1000
}

SECTIONS {
  .text : {
      *(.text)
  } >ROM1

  .data : {
      *(.data)
  } >ROM1

  .tables : {
    keyboard.o(kbdscantable)
    display.o(glyphs)
  } >ROM1

  .variables (NOLOAD) : {
      *(.variables)
  } >SYSRAM
}

