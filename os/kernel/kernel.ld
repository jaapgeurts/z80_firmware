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
  .isr_table : {
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

  .text : {
      *(.text)
  }

  .rodata1 : {
      *(.rodata)
  }

  .rodata2 : {
    keyboard.o(kbdscantable)
    display.o(glyphs)
  }

  .fill : {
    FILL8(0x00);
    RESERVE(0x2000 - .);
  }
  . = 0xf000;

  .bss (NOLOAD) : {
      display.o(.bss)
      . = ALIGN(60);
      kernel.o(.bss)
      *(.bss)
  }

}

