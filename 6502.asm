[bits 32]

stk 32
org 0

; we have a wild 6502 on the loose here!
; you know what that means? it means that
; it's an emulator in asmbf for an iconic
; cpu that powered a few notoriously great
; machines of the last century

; it's fucky to represent this bad boy 
; but we can try our best, can't we?

; the 6502 has:
;	-  one 8 bit accumulator A
;	-  two 8 bit indexes X and Y
;	-  one 8 bit stack pointer SP
;	-  one 8 bit processor flag register PF
;	- & a 16 bit program/instruction counter PC
;
; we store the PC in reg R6
; and the PF in reg R5 or F3 (not yet sure)
; 	the rest of the CPU's internals go
;   in the first four memory places

&reg_a
	db 0
&reg_x
	db 0
&reg_y
	db 0
&reg_sp
	db 0

; then the rest of memory is filled with
; the 6502's program's mem and executable code
; 
;	but we don't offset the 6502's memory by 4
;   and instead we're sacrificing 4 bytes of ZP

; the registers are all volatile: don't assume anything
; will be saved, and everything SHALL be trashed
; 
; the stack reservation is 32 deep so
; if there's anything worth preserving go 
; bump the stack you weirdo

; but also each opcode uses a RET at the end
; to simplify implementation
; you just push the address of where you want
; to land when you return and then use a
; JMP OPCODE to the decoder, and RET
; when done ;) 

; 	the 6502 stores two-byte values
;	with the least significant byte first aka
;	it's a little-endian system

; =============

; because we're using a jump-table design because
; holy fuck i hate doing testing shit one by one
; and this lets us do wacky things like
; fucking actually maybe implementing everything
; one instruction at a time, or in chunks
; we use the old label system
; we jump to reset_startup to bypass the opcode field

$(RESET_STARTUP = 0x100)
$(START = 0x101)

clr r1
clr r2
clr r3
clr r4
clr r5
clr r6

jmp $(RESET_STARTUP)

; the wild field of OPCODES goes here
; 	these bad boys are our fucked up jump table
;	putting them here at the start to make sure the label
;	system finds them first and then aligns them properly so that 
;	labels zero to 0xff inclusive are always predictable
;   and the other labels that the code might be using
;	will go from 256 onward
;
;
;	apart from the normal opcodes, we also
;	implement special / bonus opcodes
;	that allow the emulated 6502 to interact
;	with the world, as well as other
;	bonus shit which may be fun
;
;	the current list of funny opcodes:
;		- 0x62, 0x63, 0x64 -- print A, X, Y as ASCII
;		- 0x72, 0x73, 0x74 -- print A, X, Y as hex num
;	
; ============================= ;
; 								;
;	the output opcodes hijack	;
;	illegal opcodes 62, 63, 64  ;
;	to directly output regs 	;
;	as their ASCII values via	;
;	simple load and print. no 	;
;	defense against unprin-		;
;	-table bytes, so don't use	;
;	this for anything other		;
;	than printing letters		;
;								;
; ============================= ;

lbl $(0x62)
;	the print A opcode
rcl r1, *reg_a
out r1
ret

lbl $(0x63)
;	the print X opcode
rcl r1, *reg_x
out r1
ret

lbl $(0x64)
;	the print Y opcode
rcl r1, *reg_y
out r1
ret

; ============================= ;
; 								;
;	the hex output opcodes hi-	;
;	-jack illegal opcodes 72,	;
;	73, 74 and print them as 	;
;	hexadecimal numbers to the 	;
;	console host. can be used	;
;	even with unprintables		;
;								;
; ============================= ;

lbl $(0x72)
	rcl r1, *reg_a
	mov r2, r1
	band r2, 15
	div r1, 16
	;	so r1 stores the high nibble
	;	and the lows in r2
	add r1, .0
	cgt r1, 57
		cadd r1, 7
	out r1

	add r2, .0
	cgt r2, 57
		cadd r2, 7
	out r2
	ret

lbl $(0x73)
	rcl r1, *reg_x
	mov r2, r1
	band r2, 15
	div r1, 16
	;	so r1 stores the high nibble
	;	and the lows in r2
	add r1, .0
	cgt r1, 57
		cadd r1, 7
	out r1

	add r2, .0
	cgt r2, 57
		cadd r2, 7
	out r2
	ret

lbl $(0x74)
	rcl r1, *reg_y
	mov r2, r1
	band r2, 15
	div r1, 16
	;	so r1 stores the high nibble
	;	and the lows in r2
	add r1, .0
	cgt r1, 57
		cadd r1, 7
	out r1

	add r2, .0
	cgt r2, 57
		cadd r2, 7
	out r2
	ret

lbl $(0xea)
; NOP
ret

; ============================= ;
; 								;
;	the implicit mode opcodes 	;
;	live here! here we imple-	;
;	-ment increments, decre-	;
;	-ments, moves between regs  ;
;	but not flag operations		;
;	as those are in the next	;
;	block.						;
;								;
; ============================= ;


lbl $(0xe8)
; INX
	rcl  r1, *reg_x
	inc  r1
	band r1, 255
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move it back to memory
	ots  r1, *reg_x 
	ret 

; =======

lbl $(0xc8)
; INY
	rcl  r1, *reg_y
	inc  r1
	band r1, 255
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move it back to memory
	ots  r1, *reg_y 
	ret

; ===============
; ===============

lbl $(0xca)
; DEX
	rcl  r1, *reg_x
	dec  r1
	band r1, 255
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move it back to memory
	ots  r1, *reg_x 
	ret 

; =======

lbl $(0x88)
; DEY
	rcl  r1, *reg_y
	dec  r1
	band r1, 255
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move it back to memory
	ots  r1, *reg_y 
	ret  

; ============
; ============

lbl $(0xAA)
; TAX
	rcl r1, *reg_a
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move to X
	ots r1, *reg_x
	ret	

; ====

lbl $(0xA8)
; TAY
	rcl r1, *reg_a
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move to X
	ots r1, *reg_y
	ret	

; ====

lbl $(0x8a)
; TXA
	rcl r1, *reg_x
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move to X
	ots r1, *reg_a
	ret	

; ====

lbl $(0x98)
; TYA
	rcl r1, *reg_y
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		or r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		or r5, 128
	cend
; and move to X
	ots r1, *reg_a
	ret	

; ====

lbl $(0xba)
; TSX
	rcl r1, *reg_sp
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move to X
	ots r1, *reg_x
	ret	

; ====

lbl $(0x9a)
; TXS
	rcl r1, *reg_x
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and move to X
	ots r1, *reg_sp
	ret	

; ============================= ;
; 								;
;	flag-based implicits go 	;
;	here. i hate these lol		;
;								;
; ============================= ;

lbl $(0x18)
; CLC
	and r5, 254
	ret

lbl $(0xd8)
; CLD
	and r5, 247
	ret

lbl $(0x58)
; CLI
	and r5, 251
	ret 

lbl $(0xb8)
; CLV
	and r5, 191
	ret

; ============================= ;
;								;
;	loading into registers w/	;
; 	immediates					;
;								;
; ============================= ;

lbl $(0xa0)
; LDY imm
	inc r6
	band r6, $(0xffff)
	rcl r1, r6
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to Y register
	ots r1, *reg_y
	ret

lbl $(0xa2)
; LDX imm
	inc r6
	band r6, $(0xffff)
	rcl r1, r6
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to X register
	ots r1, *reg_x
	ret

lbl $(0xa9)
; LDA imm
	inc r6
	band r6, $(0xffff)
	rcl r1, r6
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to X register
	ots r1, *reg_a
	ret

; =======
;
;	and with zero page

lbl $(0xA5)
; LDA zpg
	inc r6
	band r6, $(0xffff)
	rcl r1, r6
	rcl r1, r1
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to X register
	ots r1, *reg_a
	ret

lbl $(0xA6)
; LDX zpg
	inc r6
	band r6, $(0xffff)
	rcl r1, r6
	rcl r1, r1
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to X register
	ots r1, *reg_x
	ret

lbl $(0xA4)
; LDY zpg
	inc r6
	band r6, $(0xffff)
	rcl r1, r6
	rcl r1, r1
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to X register
	ots r1, *reg_y
	ret

; ========= ;
; implicits ;
; ========= ;

lbl $(0x09)
; ORA imm
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	bor  r1, r2
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to memory
	ots r1, *reg_a
	ret

lbl $(0x29)
; AND imm
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
   band r1, r2
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to memory
	ots r1, *reg_a
	ret

lbl $(0x49)
; EOR imm -- aka xor
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
   bxor r1, r2
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to memory
	ots r1, *reg_a
	ret

; ===================
; ===================

lbl $(0x69)
; ADC imm -- A + Mem + C
; r1 - reg A
; r2 - immediate
; r3 - result

	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

	mov r3, r1
	add r3, r2
	mov r4, r5
	and r4, 1
   ^add r3, r4

; now r3 is result
; r4 is the only free temporary

; if greater than 255, trip carry flag
	cgt r2, 255
	cbegin
		band r2, 255
		bor r5, 1
	cend
; if sign different from both inputs, trip overflow flag
;	 	to check this we need to reduce each of the three 
; 		constituents to their sign bits logically
;		and then (A xnor B) xor C == !(A xor B) xor C
	mov r4, r3
	and r1, 128
	and r2, 128
	and r4, 128

	xor r1, r2
	not r1
	xor r1, r4

	ceq r1, 1
	cbegin
		bor r5, 64
	cend

	mov r1, r3

; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to A register
	ots r1, *reg_a
	ret

lbl $(0xE9)
; SBC imm -- A - Mem - !C
; r1 - reg A
; r2 - immediate
; r3 - result

	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

	mov r3, r1
	sub r3, r2
	mov r4, r5
	and r4, 1
	not r4
   ^sub r3, r4

; now r3 is result
; r4 is the only free temporary

; if greater than 255, trip carry flag
	cgt r2, 255
	cbegin
		band r2, 255
		bor r5, 1
	cend
; if sign different from both inputs, trip overflow flag
;	 	to check this we need to reduce each of the three 
; 		constituents to their sign bits logically
;		and then (A xnor B) xor C == !(A xor B) xor C
	mov r4, r3
	and r1, 128
	and r2, 128
	and r4, 128

	xor r1, r2
	not r1
	xor r1, r4

	ceq r1, 1
	cbegin
		bor r5, 64
	cend

	mov r1, r3

; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to A register
	ots r1, *reg_a
	ret

; ========= ;
; zeropages ;
; ========= ;

lbl $(0x05)
; ORA zpg
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2
	bor  r1, r2
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to memory
	ots r1, *reg_a
	ret

lbl $(0x25)
; AND zpg
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2
   band r1, r2
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to memory
	ots r1, *reg_a
	ret

lbl $(0x45)
; EOR zpg -- aka xor
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2
   bxor r1, r2
; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to memory
	ots r1, *reg_a
	ret

; ===================
; ===================

lbl $(0x65)
; ADC zpg -- A + Mem + C
; r1 - reg A
; r2 - immediate
; r3 - result

	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2

	mov r3, r1
	add r3, r2
	mov r4, r5
	and r4, 1
   ^add r3, r4

; now r3 is result
; r4 is the only free temporary

; if greater than 255, trip carry flag
	cgt r2, 255
	cbegin
		band r2, 255
		bor r5, 1
	cend
; if sign different from both inputs, trip overflow flag
;	 	to check this we need to reduce each of the three 
; 		constituents to their sign bits logically
;		and then (A xnor B) xor C == !(A xor B) xor C
	mov r4, r3
	and r1, 128
	and r2, 128
	and r4, 128

	xor r1, r2
	not r1
	xor r1, r4

	ceq r1, 1
	cbegin
		bor r5, 64
	cend

	mov r1, r3

; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to A register
	ots r1, *reg_a
	ret

lbl $(0xE5)
; SBC zpg -- A - Mem - !C
; r1 - reg A
; r2 - immediate
; r3 - result

	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2

	mov r3, r1
	sub r3, r2
	mov r4, r5
	and r4, 1
	not r4
   ^sub r3, r4

; now r3 is result
; r4 is the only free temporary

; if greater than 255, trip carry flag
	cgt r2, 255
	cbegin
		band r2, 255
		bor r5, 1
	cend
; if sign different from both inputs, trip overflow flag
;	 	to check this we need to reduce each of the three 
; 		constituents to their sign bits logically
;		and then (A xnor B) xor C == !(A xor B) xor C
	mov r4, r3
	and r1, 128
	and r2, 128
	and r4, 128

	xor r1, r2
	not r1
	xor r1, r4

	ceq r1, 1
	cbegin
		bor r5, 64
	cend

	mov r1, r3

; if zero, trip zero flag => R5 or 2
	ceq  r1, 0
	cbegin
		bor r5, 2
	cend
; if MSB is set, trip neg flag => R5 or 128
	mov  f1, 128
	and  f1, r1
	cbegin
		bor r5, 128
	cend
; and store to A register
	ots r1, *reg_a
	ret

; ==== ;
; jump ;
; ==== ;

lbl $(0x4c)
; JMP imml immh
	inc r6
	band r6, $(0xffff)
	rcl r1, r6

	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	mul r2, 256

   ^mov r6, r1
   ^add r6, r2

   ret

lbl $(0x10)
 ; BPL offset aka branch on plus aka bit 7 not set
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 127
    cjz $(0x110)
    ret
	lbl $(0x110)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

lbl $(0x30)
 ; BMI offset aka branch on minus aka bit 7 yes set
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 127
    cjn $(0x130)
    ret
	lbl $(0x130)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

lbl $(0xD0)
 ; BNE offset aka branch on non-zero aka bit 2 not set
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 2
    cjz $(0x1D0)
    ret
	lbl $(0x1D0)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

lbl $(0x50)
 ; BVC offset aka branch on overflow clear
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 64
    cjz $(0x150)
    ret
	lbl $(0x150)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

lbl $(0x70)
 ; BVS offset aka branch on overflow set
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 64
    cjn $(0x170)
    ret
	lbl $(0x170)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

lbl $(0x90)
 ; BCC offset aka branch on carry clear
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 1
    cjz $(0x190)
    ret
	lbl $(0x190)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

lbl $(0xB0)
 ; BCS offset aka branch on carry set
 	inc r6
	 	band r6, $(0xffff)
    mov f1, r5
    and f1, 1
    cjn $(0x1B0)
    ret
	lbl $(0x1B0)
	rcl r1, r6
	sub r6, 128
   ^add r6, r1
    ret

; ============-= ;
;				 ;
;	comparison	 ;
;   discards     ;
;   results of   ;
;   subtraction  ;
;			     ;
; ============== ;

lbl $(0xc9)
; CMP/CPA imm
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

   ^sub r1, r2

    cge r1, 0
    cbegin
    	bor r5, 1
    cend
    cne r1, 0
    not f1
    bor r5, f1

   band r1, 128
    bor r5, r1

    ret

lbl $(0xe0)
; CPX imm
	rcl r1, *reg_x
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

   ^sub r1, r2

    cge r1, 0
    cbegin
    	bor r5, 1
    cend
    cne r1, 0
    not f1
    bor r5, f1

   band r1, 128
    bor r5, r1

    ret

lbl $(0xc0)
; CPY imm
	rcl r1, *reg_y
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

   ^sub r1, r2

    cge r1, 0
    cbegin
    	bor r5, 1
    cend
    cne r1, 0
    not f1
    bor r5, f1

   band r1, 128
    bor r5, r1

    ret

; and zpg

lbl $(0xc5)
; CMP/CPA zpg
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2

   ^sub r1, r2

    cge r1, 0
    cbegin
    	bor r5, 1
    cend
    cne r1, 0
    not f1
    bor r5, f1

   band r1, 128
    bor r5, r1

    ret

lbl $(0xe4)
; CPX zpg
	rcl r1, *reg_x
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2, r2

   ^sub r1, r2

    cge r1, 0
    cbegin
    	bor r5, 1
    cend
    cne r1, 0
    not f1
    bor r5, f1

   band r1, 128
    bor r5, r1

    ret

lbl $(0xc4)
; CPY zpg
	rcl r1, *reg_y
	inc r6
	band r6, $(0xffff)
	rcl r2, r6
	rcl r2,

   ^sub r1, r2

    cge r1, 0
    cbegin
    	bor r5, 1
    cend
    cne r1, 0
    not f1
    bor r5, f1

   band r1, 128
    bor r5, r1

    ret

; ================== ;
;					 ;
;	store to memory  ;
;                    ;
; ================== ;

lbl $(0x84)
;STY zpg
	rcl r1, *reg_y
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

	ots r1, r2
	ret

lbl $(0x85)
;STA zpg
	rcl r1, *reg_a
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

	ots r1, r2
	ret

lbl $(0x86)
;STX zpg
	rcl r1, *reg_x
	inc r6
	band r6, $(0xffff)
	rcl r2, r6

	ots r1, r2
	ret



; =================================	;
;								   	;
; 	when the CPU boots or resets   	;
;	it has to read from ROM at 	   	;
;	mems 0xfffc -- 0xfffd, which	;
;	loads the first address into 	;
;	the program counter. then it 	;
;	starts executing from that		;
;	location. this means that 		;
; 	the locations in fffa-ffff		;
;	have to be read-only and be 	;
;	visible at startup, before we 	;
;   have a chance to even write 	;
;	to RAM							;
;									;
;	of course, this is RAM for us 	;
;	even if its not RAM for the 	;
;	old school devs of 6502-based 	;
;	machines. 						;
;	how cool is that!				;
;									;
; ================================= ;

lbl $(RESET_STARTUP)
;	make sure we're using clean IC
clr r6

rcl r2, $(0xfffc)
rcl r3, $(0xfffd)
; 65532 -- fffc = low byte  in r2
; 65533 -- fffd = high byte in r3
;	now we use destructive addition to
;	fill the r6, and then we jump into start
^add r6, r2
mul  r3, 256
^add r6, r3
 add r6, 4
 ;	gotta add 4 to dodge registers

jmp $(START)

; the actual execution starts here, jumping from top
;	fundamentally, the process is simplex
;
;	the loop roughly looks like:
;		
;       1) recall to r1 from current val of r6
;	  /	2) increment r6
;	 /	3) push start label 
;	 \	4) jump to opcode
;	  \		4.1) resolve opcode
;	   \    4.2) maybe load more bytes (frequent!)
;	    5) return to start
;
;	you even get a shitty diagram to go with it

lbl $(START)

rcl r1, r6
inc r6
band r6, $(0xffff)

psh $(START)

jmp r1

$(END = 0x105)
lbl $(END)

end