MEMORY {
    ROM1 : ORIGIN = 0x0000, LENGTH = 0x2000
    ROM2 : ORIGIN = 0x2000, LENGTH = 0x2000
    SYSRAM: ORIGIN = 0xf000, LENGTH = 0x1000
}

SECTIONS {

  . = 0x0000;

  .start : {
      kernel.o(.start)
  }

  . = 0x0008;
  .rst_table : {
    kernel.o(.rst_table)
  }

  . = 0x0038;
  .isr_int : {
     kernel.o(.isr_int)
  }

  . = 0x0066;
  .isr_nmi : {
     kernel.o(.isr_nmi)
  }

  .isr_table : {
      . = ALIGN(0x100);
      kernel.o(.isr_table)
  }

  .text : {
      *(.text)
  }

  /* TODO: remove later */
  . = 0x2000;

  .rodata1 : {
      *(.rodata)
  }

/*
  move to second rom later to create space
  .rodata2 : {
    keyboard.o(kbdscantable)
    display.o(glyphs)
  }
*/

  /* when changing this number also update the rorg directive in the basic source */
  . = 0x3300; 

  .basic_text : {
    tinybasic.o(.basic_text)
  }

  .fill : {
    FILL8(0x00);
    RESERVE(0x4000 - .);
  }


  .basic_bss (NOLOAD) : {
      tinybasic.o(.basic_bss)
  }

  . = 0xf000;

  .bss (NOLOAD) : {
      . = ALIGN(40);  /* alignment for text buffer equal to amount # of COLS */
      display.o(.bss)
      . = ALIGN(0x100); /* alignment for keyb buffer */
      kernel.o(.bss)
      *(.bss)
  }

  . = 0x10000 - SIZEOF(.stack);

  .stack (NOLOAD) : {
      kernel.o(.stack)
  }


}

