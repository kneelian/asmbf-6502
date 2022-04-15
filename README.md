# asmbf-6502
An asmbf based 6502 emulator.

Project RAM *and* ROM have to be loaded into asmbf code before
assembling into bf. There's currently no support for dynamically
loading program at runtime, it's all hardcoded into the bf.

Basically, imagine youre compiling a file and bundling the
brainfuck runtime environment with the C bytecode.

Nasty!