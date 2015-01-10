; JMON - 6502 Monitor Program
;
; Copyright (C) 2012-2014 by Jeff Tranter <tranter@pobox.com>
; Copyright (C) 2015 by Michał Siejak <michal@siejak.pl>
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;   http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
;
; Possible Future Enhancements:
; - use CPU type option for disassembly/assembly/trace
; - trace: support for 65C02 instructions (only need to implement BBR and BBS)
; - trace: support for 65816 instructions, including variable length
; - assembler: support for Rockwell 65C02 RMB, SMB, BBS, and BBR instructions
; - assembler: support for 65816 addressing modes
; - assembler: binary, character, decimal constants
; - disassembler: comment out more 65816 and 65C02-specific code when support is not enabled
; - refactor some common code to reduce size
; - option to use other device for I/O, e.g. ACIA on Multi I/O card
; - make some modules configurable to enable/disable to reduce code size
; - try to get down to fit in 8K (possibly with some features disabled)

; Revision History
; Version Date	       Comments
; 0.0	  19-Feb-2012  First version started
; 0.1	  21-Feb-2012  Initial release
; 0.2	  10-Mar-2012  Added search command. Avoid endless loop in PrintString if string too long.
; 0.3	  28-Mar-2012  Added Unassemble command.
; 0.4	  30-Mar-2012  Added Test and Breakpoint commands.
; 0.5	  08-May-2012  Added write delay command for slow EEPROM access
; 0.6	  15-May-2012  Support overlapping addresses in copy command
; 0.7	  16-May-2012  Prompt whether to continue when Verify detects mismatch or Search finds match.
; 0.8	  17-May-2012  Search and Fill commands now use 16 bit patterns.
; 0.9	  22-May-2012  Added M command to call CFFA1 menu.
; 0.91	  23-May-2012  Now uses smarter "option picker" for commands.
; 0.92	  03-Jun-2012  Added ":" command
; 0.93	  06-Jun-2012  Added Register command. Former Run command is now Go.
; 0.94	  17-Jun-2012  Display error in break handler if interrupt occurred.
;		       Fill command accepts variable length pattern.
;		       Search command accepts variable length pattern.
; 0.95	  18-Jun-2012  Use constants for keyboard registers.
;		       Removed reliance on Woz Mon routines.
;		       Go command now does a JSR (or equivalent) so called program can return.
;		       Added = command for simple hex math calculations (add/subtract).
; 0.96	  21-Jun-2012  Some refactoring to improve common code.
;		       Improvements to comments.
;		       Added new L command to clear screen.
;		       Moved most variables out of page zero.
;		       Added new E command for ACI cassette interface (untested).
;		       Fill, Search, and ":" commands accept characters as well as hex values.
;		       Type ' to enter a character.
; 0.97	 03-Jul-2012   Implemented new options command.
;		       Added support for 65816 to disassembler.
;		       Disassembler can be conditionally assembled for different CPU support.
;	 07-Jul-2012   Now adjusts disassembly of 65816 instructions for 8/16-bit modes.
;		       Also fixed missing SEP opcode (error in WDC manual).
; 0.98	 08-Jul-2012   Added mini assembler (replaces call to Krusader)
; 0.99	 11-Jul-2012   Added trace feature (replaces call to Krusader mini monitor).
;	 16-Jul-2012   Add check that BASIC is present before jumping to it.
;		       Restore stack pointer after returning from Go command so we don't
;		       need to restart JMON.
;		       Processor status bits are shown in lower case if supported.
;		       Moved variables to allow program to run in ROM.
;	 18-Jul-2012   Added new iNfo command.
; 1.0	 20-Jul-2012   Bump version to 1.00.
; 1.0.1	 14-Oct-2012   Added new checKsum command.
; 1.0.2	 23-Mar-2014   Bug fixes from Dave Lyons:
;		       Properly check for top of RAM in INFO command.
;		       Fix extra code in tests for start and end addresses.
;		       Factor out code for address range check into subroutine.
;		       Check if RAM test spans two pages.
;		       Optimize JSR / RTS to JMP
; 1.1	 08-Jan-2015   Ported to BENDER-I emulated computer. (Michał Siejak)
;		       Removed Apple I specific features.
;		       Replaced IO functions with calls to B1 BIOS.
;		       Added sound test menu, display options.
;		       Breakpoints feature doesn't work for the moment.

; Constants
  CR	  = $0D			; Carriage Return
  BS	  = $08			; Backspace
  SP	  = $20			; Space
  ESC	  = $1B			; Escape
  F1      = $81			; F1 key
  F12     = $8C			; F12 key

  MAXCOL  = 40			; Maximum number of screen columns
  MAXROW  = 25			; Maximum number of screen rows

; Hardware addresses
  KBDCTL  = $FD00		; Keyboard status & control
  KBDDAT  = $FD01		; Keyboard data
  BRCOLL  = $FD04		; Border color
  BRCOLH  = $FD05
  BGCOLL  = $FD06		; Background color
  BGCOLH  = $FD07
  FGCOLL  = $FD08		; Foreground color
  FGCOLH  = $FD09
  AUDCTL  = $FD0C		; Audio control
  AUDFRQ  = $FD0D		; Audio frequency
  VRAM	  = $F000		; VRAM start

; BIOS functions
  GETCHR  = $FF03
  PUTCHR  = $FF06
  SCROLL  = $FF09
  CLRSCR  = $FF15

; Page Zero locations
; Note: Woz Mon uses $24 through $2B and $0200 through $027F.
; Krusader uses $F8, $F9, $FE, $FF.
; Mini-monitor uses $0F, $10, $11, $E0-$E8, $F0-$F6.
  T1	  = $30			; Temp variable 1 (2 bytes)
  SL	  = $32			; Start address low byte
  SH	  = $33			; Start address high byte
  EL	  = $34			; End address low byte
  EH	  = $35			; End address high byte
  DL	  = $36			; Destination address low byte
  DH	  = $37			; Destination address high byte
  ADDR	  = $38			; Instruction address, 2 bytes (low/high)
  ADDRS	  = $3A			; Memory test - 2 bytes - address of memory
  TEST_PATRN = $3C		; Memory test - 1 byte - current test pattern
  PASSES  = $3D			; Memory test - number of passes
  VECTOR  = $3E			; Holds adddress of IRQ/BREAK entry point (2 bytes)
  BPA	  = $40			; Address of breakpoint (2 bytes * 4 breakpoints)
  
; External Routines
  BASIC	    = $E000		; BASIC
  BRKVECTOR = $FFFE		; Break/interrupt vector (2 bytes)

  .segment "JMON"
  .org $C400

; JMON Entry point
JMON:

; Initialization
	CLD			; clear decimal mode
	CLI			; clear interrupt disable

	LDA #$3			; initialize keyboard controller
	STA KBDCTL		; (set uppercase & shift translation)

	LDX #$80		; initialize stack pointer to $0180
	TXS			; so we are less likely to clobber BRK vector at $0100
	LDA #0
	STA RETOK		; Don't accept <Return> by default
	STA CHAROK		; Don't accept character input by default
	STA CHARMODE		; Not currently in char input mode
	LDA #1
	STA XBIT		; Default 65816 to 8-bit modes
	STA MBIT
	LDA #$40		; Default stack pointer for running program
	STA SAVE_S		; ($00 is bad choice since BRK vector is at $0100)
;	JSR BPSETUP		; initialization for breakpoints
	JSR ClearScreen

; Display Welcome message
	LDX #<WelcomeMessage
	LDY #>WelcomeMessage
	JSR PrintString

MainLoop:
; Display prompt
	LDX #<PromptString
	LDY #>PromptString
	JSR PrintString

; Get first character of command
	JSR GETCHR

; Call option picker to run appropriate command
	JSR OPICK
	JMP MainLoop

; Invalid command
Invalid:
	LDX #<InvalidCommand
	LDY #>InvalidCommand
	JMP PrintString		; Return via caller

; Display help
Help:
	LDX #<HelpString
	LDY #>HelpString
	JMP PrintString		; Return via caller

; Go to Mini Assembler
Assemble:
	JSR PUTCHR		; echo command
	JSR PrintSpace		; print a space
	JSR GetAddress		; Get start address
	STX ADDR		; Save it
	STY ADDR+1		; Save it
	JSR PrintCR		; Start new line
	JMP AssembleLine	; Call asssembler

; Go to BASIC

Basic:
	JSR BASICPresent       ; Is BASIC ROM present?
	BEQ NoBasic
	JMP BASIC		; Jump to BASIC (no facility to return).
NoBasic:
	LDX #<NoBASICString	; Display error that no BASIC is present.
	LDY #>NoBASICString
	JMP PrintString

; Handle breakpoint
; B ?			 <- list status of all breakpoints
; B <n> <address>	 <- set breakpoint number <n> at address <address>
; B <n> 0000		 <- remove breakpoint <n>
; <n> is 0 through 3.
Breakpoint:
	JSR PUTCHR		; echo command
	JSR PrintSpace		; print space
IGN:	JSR GETCHR		; get breakpoint number
	CMP #'?'		; ? lists breakpoints
	BEQ LISTB
	CMP #ESC		; <Escape> cancels
	BNE Num
	JMP PrintCR

Num:	CMP #'0'		; is it 0 through 3?
	BMI IGN			; Invalid, ignore and try again
	CMP #'3'+1
	BMI VALIDBP
	JMP IGN
VALIDBP:
	JSR PUTCHR		; echo number
	SEC
	SBC #'0'		; convert to number
	PHA			; save it
	JSR PrintSpace		; print space
	JSR GetAddress		; prompt for address
	JSR PrintCR
	PLA			; restore BP number
	JMP BPADD

LISTB:	JSR PrintCR
	JMP BPLIST

; Hex to decimal conversion command
Hex:
	JSR PUTCHR		; echo command
	JSR PrintSpace		; print space
	JSR GetAddress		; prompt for address
	STX BIN			; store address
	STY BINH
	JSR PrintSpace
	LDA #'='
	JSR PUTCHR
	JSR PrintSpace

; If value as 16-bit signed is negative (high bit set) display a minus
; signed and convert to 2's complement.

	LDA BINH	; MS byte
	BPL @plus	; not negative
	EOR #$FF	; complement the bits
	STA BINH
	LDA BIN		; LS byte
	EOR #$FF	; complement the bits
	STA BIN
	CLC
	ADC #1	       ; add one with possible carry
	STA BIN
	LDA BINH
	ADC #0
	STA BINH
	LDA #'-'
	JSR PUTCHR
@plus:
	JSR BINBCD16
	LDA #0
	STA LZ
	STA LAST
	LDA BCD+2
	JSR PrintByteLZ
	LDA BCD+1
	JSR PrintByteLZ
	LDA #1			; no leading zero suppression for last digit
	STA LAST
	LDA BCD
	JSR PrintByteLZ
	JMP PrintCR

; Run at address
Go:
	JSR PUTCHR	; echo command
	JSR PrintSpace	; print space
	LDA #1
	STA RETOK
	JSR GetAddress	; prompt for address
	BCS RetPressed	; Branch if user pressed <Enter>
	STX SAVE_PC	; store address
	STY SAVE_PC+1

RetPressed:
	LDA SAVE_PC
	STA SL
	LDA SAVE_PC+1
	STA SL+1

	LDA #0
	STA RETOK

; Save our current stack pointer value

	TSX
	STX THIS_S

; Restore saved values of registers
	LDX SAVE_S	; Restore stack pointer
	TXS
	LDA #>(@Return-1) ; Push return address-1 on the stack so an RTS in the called code will return here.
	PHA
	LDA #<(@Return-1)
	PHA
	LDA SAVE_P
	PHA		; Push P
	LDY SAVE_Y	; Restore Y
	LDX SAVE_X	; Restore X
	LDA SAVE_A	; Restore A
	PLP		; Restore P
	JMP (SL)	; jump to address
@Return:

; Restore our original stack pointer. Hopefully
;  the called program did not corrupt the stack.

	LDX THIS_S
	TXS
	JMP PrintCR

; Copy Memory
Copy:
	JSR PUTCHR	; echo command
	JSR PrintSpace	; print space
	JSR GetAddress	; prompt for start address
	STX SL		; store address
	STY SH
	JSR PrintSpace	; print space
	JSR GetAddress	; prompt for end address
	STX EL		; store address
	STY EH
	JSR PrintSpace	; print space
	JSR GetAddress	; prompt for destination address
	STX DL		; store address
	STY DH
	JSR PrintCR
	JSR RequireStartNotAfterEnd
	BCC @okay1
	RTS

; Separate copy up and down routines to handle avoid overlapping memory

@okay1:
	LDA SH
	CMP DH
	BCC @okayUp		; copy up
	BNE @okayDown		; copy down
	LDA SL
	CMP DL
	BCC @okayUp
	BCS @okayDown

@okayUp:
	LDY #0
@copyUp:
	LDA (SL),Y		; copy from source
	STA (DL),Y		; to destination
	LDA SH			; reached end yet?
	CMP EH
	BNE @NotDone1
	LDA SL
	CMP EL
	BNE @NotDone
	RTS			; done
@NotDone1:
	LDA SL			; increment start address
	CLC
	ADC #1
	STA SL
	BCC @NoCarry1
	INC SH
@NoCarry1:
	LDA DL			; increment destination address
	CLC
	ADC #1
	STA DL
	BCC @NoCarry2
	INC DH
@NoCarry2:
	JMP @copyUp

@okayDown:
	LDA EL		       ; Calculate length = End - Start
	SEC
	SBC SL
	STA T1
	LDA EH
	SBC SH
	STA T2
	LDA DL		       ; add length to Destination
	CLC
	ADC T1
	STA DL
	LDA DH
	ADC T2
	STA DH
	LDY #0
@copyDown:
	LDA (EL),Y		; copy from source
	STA (DL),Y		; to destination
	LDA EH			; reached end yet?
	CMP SH
	BNE @NotDone
	LDA EL
	CMP SL
	BNE @NotDone
	RTS			; done
@NotDone:
	LDA EL			; decrement end address
	SEC
	SBC #1
	STA EL
	BCS @NoBorrow1
	DEC EH
@NoBorrow1:
	LDA DL			; decrement destination address
	SEC
	SBC #1
	STA DL
	BCS @NoBorrow2
	DEC DH
@NoBorrow2:
	JMP @copyDown

; Search Memory
Search:
	JSR PUTCHR	; echo command
	JSR PrintSpace
	JSR GetAddress	; get start address
	STX SL
	STY SH
	JSR PrintSpace
	JSR GetAddress	; get end address
	STX EL
	STY EH
	JSR PrintSpace
	JSR GetHexBytes		; Get search pattern
	JSR PrintCR
	LDA IN			; If length of pattern is zero, return
	BNE @lenokay
	RTS

@lenokay:
	JSR RequireStartNotAfterEnd
	BCC @StartSearch
	RTS

@StartSearch:
	LDX #0			; Index into fill pattern
@search:
	LDY #0
	LDA IN+1,X		; Get byte of pattern data
	CMP (SL),Y		; compare with memory data
	BNE @NoMatch
	INX
	CPX IN			; End of pattern reached?
	BEQ @Match		; If so, found match
	BNE @PartialMatch		 
@NoMatch:
	STX T1			; Subtract X from SL,SH
	SEC
	LDA SL
	SBC T1
	STA SL
	LDA SH
	SBC #0
	STA SH
@Continue:
	LDX #0			; Reset search to end of pattern
@PartialMatch:
	LDA SH			; reached end yet?
	CMP EH
	BNE @NotDone
	LDA SL
	CMP EL
	BNE @NotDone
	LDX #<NotFound
	LDY #>NotFound
	JMP PrintString

@NotDone:
	LDA SL			; increment address
	CLC
	ADC #1
	STA SL
	BCC @NoCarry
	INC SH
@NoCarry:
	JMP @search

@Match:
	DEC IN			; Calculate start address as SL,SH minus (IN - 1)
	LDA SL
	SEC
	SBC IN
	STA SL
	LDA SH
	SBC #0			; Includes possible carry
	STA SH
	INC IN
	LDX #<Found
	LDY #>Found
	JSR PrintString
	LDX SL
	LDY SH
	JSR PrintAddress
	JSR PrintCR
	JSR PromptToContinue
	BCC @Continue
	RTS		; done

; Verify Memory
Verify:
	JSR PUTCHR	; echo command
	JSR PrintSpace	; print space
	JSR GetAddress	; prompt for start address
	STX SL		; store address
	STY SH
	JSR PrintSpace	; print space
	JSR GetAddress	; prompt for end address
	STX EL		; store address
	STY EH
	JSR PrintSpace	; print space
	JSR GetAddress	; prompt for destination address
	STX DL		; store address
	STY DH
	JSR PrintCR

	JSR RequireStartNotAfterEnd
	BCC @verify
	RTS

@verify:
	LDY #0
	LDA (SL),Y		; compare source
	CMP (DL),Y		; to destination
	BEQ @match
	LDX #<MismatchString	; report mismatch
	LDY #>MismatchString
	JSR PrintString
	LDX SL
	LDY SH
	JSR PrintAddress
	LDA #':'
	JSR PUTCHR
	JSR PrintSpace
	LDY #0
	LDA (SL),Y
	JSR PrintByte
	JSR PrintSpace
	LDX DL
	LDY DH
	JSR PrintAddress
	LDA #':'
	JSR PUTCHR
	JSR PrintSpace
	LDY #0
	LDA (DL),Y
	JSR PrintByte
	JSR PrintCR
	JSR PromptToContinue
	BCS @Done		; ESC pressed, return
@match: LDA SH			; reached end yet?
	CMP EH
	BNE @NotDone
	LDA SL
	CMP EL
	BNE @NotDone
@Done:
	RTS			; done
@NotDone:
	LDA SL			; increment start address
	CLC
	ADC #1
	STA SL
	BCC @NoCarry1
	INC SH
@NoCarry1:
	LDA DL			; increment destination address
	CLC
	ADC #1
	STA DL
	BCC @NoCarry2
	INC DH
@NoCarry2:
	JMP @verify

; Dump Memory
Dump:
; echo 'D' and space, wait for start address
	JSR PUTCHR
	JSR PrintSpace
	JSR GetAddress		; Get start address
	STX SL
	STY SH
@line:	JSR PrintCR
	LDX #0
@loop:	JSR DumpLine		; display line of output
	LDA SL			; add 8 to start address
	CLC
	ADC #8
	STA SL
	BCC @NoCarry
	INC SH
@NoCarry:
	INX
	CPX #23			; display 23 lines
	BNE @loop
	JSR PromptToContinue
	BCC @line
	RTS

; Unassemble Memory
Unassemble:
; echo 'U' and space, wait for start address
	JSR PUTCHR
	JSR PrintSpace
	JSR GetAddress		; Get start address
	STX ADDR
	STY ADDR+1
@line:	JSR PrintCR
	LDA #23
@loop:	PHA
	JSR DISASM		; display line of output
	PLA
	SEC
	SBC #1
	BNE @loop
	JSR PromptToContinue
	BCC @line
	RTS

; Test Memory
Test:
	JSR PUTCHR		; echo command
	JSR PrintSpace
	JSR GetAddress		; get start address
	STX START
	STY START+1
	JSR PrintSpace
	JSR GetAddress		; get end address
	STX END
	STY END+1
	JSR PrintCR
	LDX #<TestString1
	LDY #>TestString1
	JSR PrintString
	LDX START
	LDY START+1
	JSR PrintAddress
	LDX #<TestString2
	LDY #>TestString2
	JSR PrintString
	LDX END
	LDY END+1
	JSR PrintAddress
	LDX #<TestString3
	LDY #>TestString3
	JSR PrintString
	JMP MEM_TEST

; Memory fill command
Fill:
	JSR PUTCHR		; echo command
	JSR PrintSpace
	JSR GetAddress		; get start address
	STX SL
	STY SH
	JSR PrintSpace
	JSR GetAddress		; get end address
	STX EL
	STY EH
	JSR PrintSpace
	JSR GetHexBytes		; Get fill pattern
	JSR PrintCR
	LDA IN			; If length of pattern is zero, return
	BNE @lenokay
	RTS
@lenokay:
	JSR RequireStartNotAfterEnd
	BCC @fill
	RTS

@fill:
	LDY #0
	LDX #0			; Index into fill pattern
@dofill:
	LDA IN+1,X		; Get next byte of fill pattern
	STA (SL),Y		; store data (first byte)
	LDA SH			; reached end yet?
	CMP EH
	BNE @NotDone
	LDA SL
	CMP EL
	BNE @NotDone
	RTS			; done
@NotDone:
	LDA SL			; increment address
	CLC
	ADC #1
	STA SL
	BCC @NoCarry
	INC SH
@NoCarry:
	INX			; increment index into pattern
	CPX IN			; end of pattern reached?
	BNE @dofill		; if not, go back
	LDX #0			; Otherwise go back to start of pattern
	JMP @dofill

; Do setup so we can support breakpoints
BPSETUP:
	LDA BRKVECTOR		; get address of BRK vector
	STA VECTOR		; and save in page zero
	LDA BRKVECTOR+1
	STA VECTOR+1
	LDA #$4C		; JMP instruction
	LDY #0		
	STA (VECTOR),Y		; store at IRQ/BRK vector
	CMP (VECTOR),Y		; if we don't read back what we wrote
	BNE VNOTINRAM		; then vector address is not writable (user may have put it in ROM)
	LDA #<BRKHANDLER	; handler address low byte
	INY
	STA (VECTOR),Y		; write it after JMP
	LDA #>BRKHANDLER	; handler address low byte
	INY
	STA (VECTOR),Y		; write it after JMP
	LDA #0			; Mark all breakpoints as cleared (BPA and BPD set to 0)
	LDX #0
	LDY #0
CLEAR:
	STA BPA,Y
	STA BPA+1,Y
	STA BPD,X
	INY
	INY
	INX
	CPX #4
	BNE CLEAR
	RTS
VNOTINRAM:
	LDX #<VNotRAMString
	LDY #>VNotRAMString
	JMP PrintString

BNOTINRAM:
	LDX #<BNotRAMString
	LDY #>BNotRAMString
	JMP PrintString

; List breakpoints, e.g.
; "BREAKPOINT n AT $nnnn"
BPLIST:
	LDX #0
LIST:
	TXA
	PHA
	LDX #<KnownBPString1
	LDY #>KnownBPString1
	JSR PrintString
	PLA
	PHA
	LSR A			; divide by 2
	JSR PRHEX
	LDX #<KnownBPString2
	LDY #>KnownBPString2
	JSR PrintString
	PLA
	PHA
	TAX
	LDA BPA,X
	INX
	LDY BPA,X
	TAX
	JSR PrintAddress
	JSR PrintCR
	PLA
	TAX
	INX
	INX
	CPX #8
	BNE LIST
	RTS

; Return 1 in A if breakpoint number A exists, otherwise return 0.
BPEXISTS:
	ASL A			; need to multiply by 2 to get offset in array
	TAX
	LDA BPA,X
	BNE EXISTS
	LDA BPA+1,X
	BNE EXISTS
	LDA #0
	RTS
EXISTS:
	LDA #1
	RTS

; Add breakpoint number A at address in X,Y
BPADD:
	STX T1
	STY T2
	PHA
	JSR BPEXISTS		; if breakpoint already exists, remove it first
	BEQ ADDIT
	PLA
	PHA
	JSR BPREMOVE		; remove it
ADDIT:
	PLA
	TAY
	ASL A			; need to multiply by 2 to get offset in array
	TAX
	LDA T1
	STA BPA,X		; save address of breakpoint
	LDA T2
	STA BPA+1,X
	LDA (BPA,X)		; get instruction at breakpoint address
	STA BPD,Y		; save it
	LDA #0			; BRK instruction
	STA (BPA,X)		; write breakpoint over code
	CMP (BPA,X)		; If we don't read back what we wrote
	BNE BNOTINRAM		; then address is not writable (user may have put it in ROM)
	RTS

; Remove breakpoint number A
BPREMOVE:
	PHA
	JSR BPEXISTS
	BNE OK	
	LDX #<NOBPString
	LDY #>NOBPString
	JSR PrintString
	PLA
	RTS
OK:
	PLA
	TAY
	ASL A			; multiply by 2 because table entries are two bytes
	TAX
	LDA BPD,Y		; get original instruction
	STA (BPA,X)		; restore instruction at breakpoint address
	LDA #0			; set BPA to address$0000 to clear breakpoint
	STA BPA,X
	STA BPA+1,X
	STA BPD,Y		; and clear BPD
	RTS

; Breakpoint handler
BRKHANDLER:
	STA SAVE_A		; save registers
	STX SAVE_X
	STY SAVE_Y
	PLA			; P is on stack
	STA SAVE_P
	PHA			; put P back on stack
	LDA  #%00010000		; position of B bit
	BIT  SAVE_P		; is B bit set, indicating BRK and not IRQ?
	BNE  BREAK		; If so, got to break handler
	JSR  PrintCR		; Otherwise print message that we got an interrupt
	LDX  #<IntString	
	LDY  #>IntString
	JSR  PrintString
	LDY  SAVE_Y
	LDX  SAVE_X		; Restore registers and return from interrupt
	LDA  SAVE_A
	RTI
BREAK:
	TSX			; get stack pointer
	SEC			; subtract 2 from return address to get actual instruction address
	LDA $0102,X
	SBC #2
	STA $0102,X		; put original instruction address back on stack
	STA SAVE_PC		; also save it for later reference
	LDA $0103,X
	SBC #0
	STA $0103,X
	STA SAVE_PC+1
	LDX #0
CHECKADDR:
	LDA SAVE_PC		; see if PC matches address of a breakpoint
	CMP BPA,X
	BNE TRYNEXT
	LDA SAVE_PC+1
	CMP BPA+1,X
	BEQ MATCHES
TRYNEXT:
	INX
	INX
	CPX #8			; last breakpoint reached
	BNE CHECKADDR
UNKNOWN:
	JSR PrintCR
	LDX #<UnknownBPString
	LDY #>UnknownBPString
	JSR PrintString
	LDX SAVE_PC
	LDY SAVE_PC+1
	JSR PrintAddress
	JMP RESTORE
MATCHES:
	TXA
	PHA
	JSR PrintCR
	LDX #<KnownBPString1
	LDY #>KnownBPString1
	JSR PrintString
	PLA			 ; get BP # x2
	PHA			 ; save it again
	LSR A			 ; divide by 2 to get BP number
	JSR PRHEX
	LDX #<KnownBPString2
	LDY #>KnownBPString2
	JSR PrintString
	LDX SAVE_PC
	LDY SAVE_PC+1
	JSR PrintAddress
	PLA
	LSR A
	JSR BPREMOVE
RESTORE:
	JSR PrintCR
	JSR PrintRegisters	; Print current values
	LDA SAVE_PC		; Disassemble current instruction
	STA ADDR
	LDA SAVE_PC+1
	STA ADDR+1
	JSR DISASM
	JMP MainLoop	       ; Continue with JMon main command loop

; Memory write command.
; Format:
; : <addr> <bb> <bb> ... <Enter> or <Esc> (up to 255 chars)
; eg:
; : A000 12 34 56 78
Memory:
	JSR PUTCHR		; Echo command
	JSR PrintCR
	JSR GetAddress		; Get start address (ESC will exit)
	STX SL
	STY SH
	LDA #1
	STA CHAROK		; Set flag to accept character input
writeLoop:
	JSR PrintSpace		; Echo space
	JSR GetByte		; Get data byte (ESC will exit)
	LDY #0
	STA (SL),Y		; write data to address
	CMP (SL),Y
	BEQ Okay
	LDX #<ReadString	; Display message that same data not written back
	LDY #>ReadString
	JSR PrintString
	LDY #0
	LDA (SL),Y
	JSR PrintByte
	JSR PrintSpace
Okay:
	CLC			; increment address
	LDA SL
	ADC #1
	STA SL
	BCC nocarry
	INC SH
nocarry:
	LDA #$07		; Is address a multiple of 8?
	BIT SL
	BNE writeLoop		; If not, keep getting data
	JSR PrintCR		; Otherwise start new line
	LDX SL
	LDY SH
	JSR PrintAddress	; Display current address
	JMP writeLoop		; Input more data

; Register change command.
; Displays and sets values of registers
; Values are set when JMON is entered.
; Uses values with Go command.
;
; R A-D2 X-00 Y-04 S-01FE P-FF NVBDIZC
; FF02	 A0 7F	     LDY   #$7F
;   A-00 X-00 Y-00 S-0180 P-01
; PC-FF02
;
; Displays saved value of registers
; Prompts for new value for each register.
; <Esc> cancels at any time.

Registers:
	JSR PUTCHR		; Echo command
	JSR PrintCR

	JSR PrintRegisters	; Print current values

	LDA SAVE_PC		; Disassemble current instruction
	STA ADDR
	LDA SAVE_PC+1
	STA ADDR+1
	JSR DISASM

	LDA #1
	STA RETOK
	LDA #'A'		; Now print and prompt for new values
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	JSR GetByte
	BCS RetPressed1
	STA SAVE_A
	JMP EnterX
RetPressed1:
	LDA SAVE_A
	JSR PrintByte
EnterX:
	JSR PrintSpace
	LDA #'X'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	JSR GetByte
	BCS RetPressed2
	STA SAVE_X
	JMP EnterY
RetPressed2:
	LDA SAVE_X
	JSR PrintByte
EnterY:
	JSR PrintSpace
	LDA #'Y'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	JSR GetByte
	BCS RetPressed3
	STA SAVE_Y
	JMP EnterS
RetPressed3:
	LDA SAVE_Y
	JSR PrintByte
EnterS:
	STA SAVE_Y
	JSR PrintSpace
	LDA #'S'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	LDA #$01
	JSR PrintByte
	JSR GetByte
	BCS RetPressed4
	STA SAVE_S
	JMP EnterP
RetPressed4:
	LDA SAVE_S
	JSR PrintByte
EnterP:
	JSR PrintSpace
	LDA #'P'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	JSR GetByte
	BCS RetPressed5
	STA SAVE_P
	JMP PrintP
RetPressed5:
	LDA SAVE_P
	JSR PrintByte
PrintP:
	JSR PrintSpace
	JSR OUTP
	JSR PrintCR
	LDA #'P'
	JSR PUTCHR
	LDA #'C'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	JSR GetAddress
	BCS RetPressed6
	STX SAVE_PC
	STY SAVE_PC+1
	JMP Eol
RetPressed6:
	LDX SAVE_PC
	LDY SAVE_PC+1
	JSR PrintAddress
Eol:
	JSR PrintCR
	LDA #0
	STA RETOK
	RTS

; Print saved values of registers
PrintRegisters:
	LDA #'A'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	LDA SAVE_A
	JSR PrintByte
	JSR PrintSpace
	LDA #'X'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	LDA SAVE_X
	JSR PrintByte
	JSR PrintSpace
	LDA #'Y'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	LDA SAVE_Y
	JSR PrintByte
	JSR PrintSpace
	LDA #'S'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	LDA #01
	JSR PrintByte
	LDA SAVE_S
	JSR PrintByte
	JSR PrintSpace
	LDA #'P'
	JSR PUTCHR
	LDA #'-'
	JSR PUTCHR
	LDA SAVE_P
	JSR PrintByte
	JSR PrintSpace
	JSR OUTP
	JMP PrintCR

; Prompt user to change display options
Options:
	LDX #<OptionsString
	LDY #>OptionsString
	JSR PrintString

	LDX #<BorderColorString
	LDY #>BorderColorString
	JSR PrintString
	JSR GetAddress
	STX BRCOLL
	STY BRCOLH
	JSR PrintCR

	LDX #<BackgroundColorString
	LDY #>BackgroundColorString
	JSR PrintString
	JSR GetAddress
	STX BGCOLL
	STY BGCOLH
	JSR PrintCR

	LDX #<ForegroundColorString
	LDY #>ForegroundColorString
	JSR PrintString
	JSR GetAddress
	STX FGCOLL
	STY FGCOLH

@Return:
	JMP PrintCR

; Math command. Add or substract two 16-bit hex numbers.
; Format: = <ADDRESS> +/- <ADDRESS>
; e.g.
; = 1234 + 0077 = 12AB
; = FF00 - 0002 = FEFE
Math:
	JSR PUTCHR		; Echo command
	JSR PrintSpace
	JSR GetAddress		; Get first number
	STX SL
	STY SH
	JSR PrintSpace
@PlusOrMinus:
	JSR GETCHR
	CMP #'+'		; Is it plus?
	BEQ @Okay
	CMP #'-'		; Is it minus?
	BEQ @Okay
	JMP @PlusOrMinus	; If not, try again
@Okay:
	STA OP
	JSR PUTCHR
	JSR PrintSpace
	JSR GetAddress		; Get second number
	STX EL
	STY EH
	JSR PrintSpace
	LDA #'='
	JSR PUTCHR
	JSR PrintSpace
	LDA OP
	CMP #'-'
	BEQ @Sub		; Branch if operation is subtract

	CLC			; Calculate DL,DH = SL,SH + EL,EH
	LDA SL
	ADC EL
	STA DL
	LDA SH
	ADC EH
	STA DH
	JMP @PrintResult

@Sub:
	SEC			; Calculate DL,DH = SL,SH - EL,EH
	LDA SL
	SBC EL
	STA DL
	LDA SH
	SBC EH
	STA DH

@PrintResult:
	LDX DL			; Print the result
	LDY DH
	JSR PrintAddress
	JMP PrintCR

; Checksum command. Sum memory bytes in a range and show 16-bit result.
; Format: K <start> <end>
; e.g.
; K C100 C1FF 1234
Checksum:
	JSR PUTCHR		; echo command
	JSR PrintSpace		; print space
	JSR GetAddress		; prompt for start address
	STX SL			; store address
	STY SH
	JSR PrintSpace		; print space
	JSR GetAddress		; prompt for end address
	STX EL			; store address
	STY EH
	JSR PrintSpace		; print space

	JSR RequireStartNotAfterEnd
	BCC @okay1
	RTS

@okay1:
	LDA #0			; Initialize checkum to zero
	STA DL
	STA DH
	LDY #0
@CalcSum:
	LDA (SL),Y		; read a byte
	CLC
	ADC DL			; add to sum
	STA DL
	BCC @NoCarry1
	INC DH			; add carry to upper byte of sum
@NoCarry1:
	LDA SH			; reached end yet?
	CMP EH
	BNE @NotDone
	LDA SL
	CMP EL
	BNE @NotDone

	LDX DL			; Get checksum value
	LDY DH
	JSR PrintAddress	; Print it
	JMP PrintCR

@NotDone:
	LDA SL			; increment start address
	CLC
	ADC #1
	STA SL
	BCC @NoCarry2
	INC SH
@NoCarry2:
	JMP @CalcSum

; Reboot command
; This function does not return.
Reboot:
	JMP ($FFFC)		; Jump to RESET vector

; -------------------- Utility Functions --------------------

; Generate one line of output for the dump command.
; Displays 8 bytes of memory
; Starting address in SL,SH.
; Registers changed: None
DumpLine:
	PHA			; save A
	TXA
	PHA			; Save X
	TYA
	PHA			; Save Y
	LDX SL			; Get start address
	LDY SH
	JSR PrintAddress	; Display address
	JSR PrintSpace		; and then a space
	LDY #0
@loop1: LDA (SL),Y		; Get byte of data from memory
	JSR PrintByte		; Display it in hex
	JSR PrintSpace		; Followed by space
	INY
	CPY #8			; Print 8 bytes per line
	BNE @loop1
	JSR PrintSpace
	LDY #0
@loop2: LDA (SL),Y		; Now get the same data
	JSR PrintAscii		; Display it in ASCII
	INY
	CPY #8			; 8 characters per line
	BNE @loop2
	JSR PrintCR		; new line
	PLA			; Restore Y
	TAY
	PLA			; Restore X
	TAX
	PLA			; Restore A
	RTS

; Gets a hex digit (0-9,A-F). Echoes character as typed.
; ESC key cancels command and goes back to command loop.
; If RETOK is zero, ignore Return key.
; If RETOK is non-zero, pressing Return will cause it to return with A=0 and carry set.
; If CHAROK is non-zero, pressing a single quote allows entering a character.
; Ignores invalid characters. Returns binary value in A
; Registers changed: A
GetHex:
	JSR GETCHR
	CMP #ESC		; ESC key?
	BNE @checkRet
	JSR PrintCR
	PLA			; pop return address on stack
	PLA
	LDA #0
	STA CHAROK		; Clear flag to accept character input
	JMP MainLoop		; Abort command
@checkRet:
	CMP #CR			; Return key?
	BNE @next
	LDA RETOK		; Flag set to check for return?
	BEQ GetHex		; If not, ignore Return key
	LDA #0
	SEC			; Carry set indicates Return pressed
	RTS
@next:
	CMP #'''		; Single quote for character input?
	BNE @next1
	LDA CHAROK		; Are we accepting character input?
	BEQ GetHex		; If not, ignore character
	LDA #'''		; Echo a quote
	JSR PUTCHR
	LDA #1			; Set flag that we are in character input mode
	STA CHARMODE
	JSR GETCHR		; Get a character

@NoConv:
	JSR PUTCHR		; Echo it
	PHA			; Save the character
	LDA #'''		; Echo a quote
	JSR PUTCHR
	PLA			; Restore the character
	CLC			; Normal return
	RTS
@next1:
	CMP #'0'
	BMI GetHex		; Invalid, ignore and try again
	CMP #'9'+1
	BMI @Digit
	CMP #'A'
	BMI GetHex		; Invalid, ignore and try again
	CMP #'F'+1
	BMI @Letter
	JMP GetHex		; Invalid, ignore and try again
@Digit:
	JSR PUTCHR		; echo
	SEC
	SBC #'0'		; convert to value
	CLC
	RTS
@Letter:
	JSR PUTCHR		; echo
	SEC
	SBC #'A'-10		; convert to value
	CLC
	RTS

; Get Byte as 2 chars 0-9,A-F
; Echoes characters as typed.
; Ignores invalid characters
; Returns byte in A
; If RETOK is zero, ignore Return key.
; If RETOK is non-zero, pressing Return as first character will cause it to return with A=0 and carry set.
; If CHAROK is non-zero, pressing a single quote allows entering a character.
; Registers changed: A
GetByte:
	JSR GetHex
	BCC @NotRet
	RTS			; <Return> was pressed, so return
@NotRet:
	PHA			; Save character
	LDA CHARMODE		; Are we in character input mode?
	BEQ @Normal
	LDA #0			; If so, we got our byte as a character. Clear charmode.
	STA CHARMODE
	CLC
	PLA			; Restore character
	RTS			; Normal return
@Normal:
	PLA
	ASL
	ASL
	ASL
	ASL
	STA T1			; Store first nybble
	LDA CHAROK		; Get value of CHAROK
	STA T2			; Save it
	LDA #0
	STA CHAROK		; Disable char input for second nybble of a byte
@IgnoreRet:
	JSR GetHex
	BCS @IgnoreRet		; If <Return> pressed, ignore it and try again
	CLC
	ADC T1			; Add second nybble
	STA T1			; Save it
	LDA T2			; Restore value of CHAROK
	STA CHAROK
	LDA T1			; Get value to return
	RTS

; Get Address as 4 chars 0-9,A-F
; Echoes characters as typed.
; Ignores invalid characters
; Returns address in X (low), Y (high)
; Registers changed: X, Y
GetAddress:
	PHA			; Save A
	JSR GetByte		; Get the first (most significant) hex byte
	BCS @RetPressed		; Quit if Return pressed
	TAY			; Save in Y
	LDA #0
	STA RETOK		; One byte already entered so can't hit return now for default.
	JSR GetByte		; Get the second (least significant) hex byte
	TAX			; Save in X
@RetPressed:
	PLA			; Restore A
	RTS

; Print 16-bit address in hex
; Pass byte in X (low) and Y (high)
; Registers changed: None
PrintAddress:
	PHA			; Save A
	TYA			; Get low byte
	JSR PRBYTE		; Print it
	TXA			; Get high byte
	JSR PRBYTE		; Print it
	PLA			; Restore A
	RTS

; Print byte in BCD with leading zero suppression
; Pass byte in A
; Registers changed: None
; Call first time with LZ cleared
PrintByteLZ:
; Check for special case: number is $00, LZ is 0, LAST is 1
; Last 0 should not be suppressed since it is the final one in $0000
	CMP #$00
	BNE @normal
	PHA
	LDA LZ
	BNE @pull
	LDA LAST
	BEQ @pull
	LDA #'0'
	JSR PUTCHR
	PLA
	RTS
@pull: PLA
@normal:
	PHA			; save for lower nybble
	AND #$F0		; mask out upper nybble
	LSR			; shift into lower nybble
	LSR
	LSR
	LSR
	CLC
	ADC #'0'
	JSR PUTCHRLZ
	PLA			; restore value
	AND #$0F		; mask out lower nybble
	CLC
	ADC #'0'
	JMP PUTCHRLZ

; Print character but suppress 0 if LZ it not set.
; Sets LZ when non-zero printed.
; Pass char in A
PUTCHRLZ:
	CMP #'0'		; is it 0?
	BNE @notzero		; if not, print it normally
	PHA
	LDA LZ			; is LZ zero?
	BNE @print
	PLA
	RTS			; suppress leading zero
@print: PLA
	JMP PUTCHR

@notzero:
	JSR PUTCHR		; print it
	LDA #1			; set LZ to 1
	STA LZ
	RTS

; Print byte as ASCII character or "."
; Pass character in A.
; Registers changed: None
PrintAscii:
	CMP #$20		; first printable character (space)
	BMI NotAscii
	CMP #$7E+1		; last printable character (~)
	BPL NotAscii
	JMP PUTCHR

NotAscii:
	PHA			; save A
	LDA #'.'
	JSR PUTCHR
	PLA			; restore A
	RTS

; Print a carriage return
; Registers changed: None
PrintCR:
	PHA
	LDA #CR
	JSR PUTCHR
	PLA
	RTS

; Print a space
; Registers changed: None
PrintSpace:
	PHA
	LDA #SP
	JSR PUTCHR
	PLA
	RTS

; Print a string
; Pass address of string in X (low) and Y (high).
; String must be terminated in a null (zero).
; Registers changed: None
;
PrintString:
	PHA		; Save A
	TYA
	PHA		; Save Y
	STX T1		; Save in page zero so we can use indirect addressing
	STY T1+1
	LDY #0		; Set offset to zero
@loop:	LDA (T1),Y	; Read a character
	BEQ done	; Done if we get a null (zero)
	JSR PUTCHR	; Print it
	CLC		; Increment address
	LDA T1		; Low byte
	ADC #1
	STA T1
	BCC @nocarry
	INC T1+1	; High byte
@nocarry:
	JMP @loop	; Go back and print next character
done:	
	PLA
	TAY		; Restore Y
	PLA		; Restore A
	RTS

; Print byte as two hex chars.
; Taken from Woz Monitor PRBYTE routine ($FFDC).
; Pass byte in A
; Registers changed: A
PrintByte:
PRBYTE:
	PHA		; Save A for LSD.
	LSR
	LSR
	LSR		; MSD to LSD position.
	LSR
	JSR PRHEX	; Output hex digit.
	PLA		; Restore A.
			; Falls through into PRHEX routine

; Print nybble as one hex digit.
; Take from Woz Monitor PRHEX routine ($FFE5).
; Pass byte in A
; Registers changed: A
PRHEX:
	AND #$0F	; Mask LSD for hex print.
	ORA #'0'	; Add "0".
	CMP #$3A	; Digit?
	BMI @Print	; Yes, output it.
	ADC #$06	; Add offset for letter.
@Print:
	JMP PUTCHR	; Jump to PUTCHR

; Print a dollar sign
; Registers changed: None
PrintDollar:
	PHA
	LDA #'$'
	JSR PUTCHR
	PLA
	RTS

; Print ",X"
; Registers changed: None
PrintCommaX:
	PHA
	LDA #','
	JSR PUTCHR
	LDA #'X'
	JSR PUTCHR
	PLA
	RTS

; Print ",Y"
; Registers changed: None
PrintCommaY:
	PHA
	LDA #','
	JSR PUTCHR
	LDA #'Y'
	JSR PUTCHR
	PLA
	RTS

; Print ",S"
; Registers changed: None
PrintCommaS:
	PHA
	LDA #','
	JSR PUTCHR
	LDA #'S'
	JSR PUTCHR
	PLA
	RTS

; Print "($"
; Registers changed: None
PrintLParenDollar:
	PHA
	LDA #'('
	JSR PUTCHR
	LDA #'$'
	JSR PUTCHR
	PLA
	RTS

; Print "[$"
; Registers changed: None
PrintLBraceDollar:
	PHA
	LDA #'['
	JSR PUTCHR
	LDA #'$'
	JSR PUTCHR
	PLA
	RTS

; Print a right parenthesis
; Registers changed: None
PrintRParen:
	PHA
	LDA #')'
	JSR PUTCHR
	PLA
	RTS

; Print a right brace
; Registers changed: None
PrintRBrace:
	PHA
	LDA #']'
	JSR PUTCHR
	PLA
	RTS

; Print several space characters.
; X contains number of spaces to print.
; Registers changed: X
PrintSpaces:
	PHA			; save A
	LDA #' '
	JSR PUTCHRs
	PLA			; restore A
	RTS

; Output a character multiple times
; A contains character to print.
; X contains number of times to print.
; Registers changed: X
PUTCHRs:
	JSR PUTCHR
	DEX
	BNE PUTCHRs
	RTS

; Ask user whether to continue or not. Returns with carry clear if
; user selected <space> to continue, carry set if user selected <ESC>
; to stop.
; Registers changed: none

PromptToContinue:
	PHA			; save registers
	TXA
	PHA
	TYA
	PHA
	LDX #<ContinueString
	LDY #>ContinueString
	JSR PrintString
@SpaceOrEscape:
	JSR GETCHR
	CMP #' '
	BEQ @Cont
	CMP #ESC
	BNE @SpaceOrEscape
	SEC			; carry set indicates ESC pressed
	BCS @Ret
@Cont:
	CLC
@Ret:
	JSR PrintCR
	PLA			; restore registers
	TAY
	PLA
	TAX
	PLA	   
	RTS

; Check if start address in SH/EH is less than or equal to end address
; in EH/EL. If so, return with carry clear. If not, print error
; message and return with carry set.
RequireStartNotAfterEnd:
; Check that start address <= end address
	LDA SH
	CMP EH
	BCC @rangeOkay
	BNE @rangeInvalid
	LDA SL
	CMP EL
	BCC @rangeOkay
	BEQ @rangeOkay
@rangeInvalid:
	LDX #<InvalidRange
	LDY #>InvalidRange
	JSR PrintString
	SEC
	RTS
@rangeOkay:
	CLC
	RTS

; Option picker. Adapted from "Assembly Cookbook for the Apple II/IIe" by Don Lancaster.
; Call with command letter in A.
; Registers affected: X
OPICK:
	TAY			; save A
	LDX #MATCHN		; Get legal number of matches
SCAN:	CMP MATCHFL,X		; Search for a match
	BEQ GOTMCH		; Found
	DEX			; Try next
	BPL SCAN

GOTMCH: INX			; Makes zero a miss
	TXA			; Get jump vector
	ASL A			; Double pointer
	TAX
	LDA JMPFL+1,X		; Get page address first!
	PHA			; and force on stack
	LDA JMPFL,X		; Get position address
	PHA			; and force on stack
	TYA			; restore A
	RTS			; Jump via forced subroutine return

; Matchn holds the number of matches.
; Matchfl holds the legal characters.
; JMPFL holds the jump vectors (minus 1).

	MATCHN = JMPFL-MATCHFL

MATCHFL:
	.byte "ABCDFGHIKLMNORSTUV:=.",F1,F12

JMPFL:
	.word Invalid-1
	.word Assemble-1
	.word Breakpoint-1
	.word Copy-1
	.word Dump-1
	.word Fill-1
	.word Go-1
	.word Hex-1
	.word Basic-1
	.word Checksum-1
	.word ClearScreen-1
	.word SoundTest-1
	.word Info-1
	.word Options-1
	.word Registers-1
	.word Search-1
	.word Test-1
	.word Unassemble-1
	.word Verify-1
	.word Memory-1
	.word Math-1
	.word Trace-1
	.word Help-1
	.word Reboot-1

; String input routine.
; Enter characters from the keyboard terminated in <Return> or <ESC>.
; Characters are echoed.
; Can be up to 127 characters.
; Returns:
;   Length stored at IN (doesn't include zero byte).
;   Characters stored starting at IN+1 ($0201-$027F, same as Woz Monitor)
;   String is terminated in a 0 byte.
;   Carry set if user hit <Esc>, clear if used <Enter> or max string length reached.
; Registers changed: A, X

; List of characters to accept. First byte is the length of the list.
FilterChars:
	.byte 22, "0123456789ABCDEF#(),XY"

GetLine:
	LDX #0			; Initialize index into buffer
loop:
	JSR GETCHR		; Get character from keyboard
	CMP #CR			; <Enter> key pressed?
	BEQ EnterPressed	; If so, handle it
	CMP #ESC		; <Esc> key pressed?
	BEQ EscapePressed	; If so, handle it
	CMP #BS			; <Backspace> key pressed?
	BEQ BackspacePressed	; If so, handle it

; Make sure character is included in the set of filter characters,
; otherwise ignore it.

	LDY FilterChars		; Get length of filter chars list
Filter:
	CMP FilterChars,Y	; Compare character from filter list with entered character
	BEQ CharOkay		; If it matched, accept character
	DEY			; Move to next character in filter list
	BNE Filter		; Try next filter char until done
	BEQ loop		; End reached, ignore the character

CharOkay:
	JSR PUTCHR		; Echo the key pressed
	STA IN+1,X		; Store character in buffer (skip first length byte)
	INX			; Advance index into buffer
	CPX #$7E		; Buffer full?
	BEQ EnterPressed	; If so, return as if <Enter> was pressed
	BNE loop		; Always taken
BackspacePressed:
	CPX #0			; If already at index 0 do nothing
	BEQ loop
	JSR PUTCHR		; Echo backspace to terminal
	DEX			; Decrement index
	LDA #0			; Store 0 in buffer (skip first length byte)
	STA IN+1,X
	JMP loop		; Always taken

EnterPressed:
	CLC			; Clear carry to indicate <Enter> pressed and fall through
EscapePressed:
	LDA #0
	STA IN+1,X		; Store 0 at end of buffer
	STX IN			; Store length of string
	RTS			; Return

; Variable length hex number input routine.
; Enter hex bytes from the keyboard terminated in <Return> or <ESC>.
; Characters are echoed.
; Can be up to 127 bytes.
; Returns:
;   Length stored at IN.
;   Characters stored starting at IN+1 ($0201-$027F, same as Woz Monitor)
; Registers changed: A, X

GetHexBytes:
	LDA #1
	STA RETOK		; Set flag to accept <Return> key
	STA CHAROK		; Set flag to accept character input
	LDX #0			; Initialize index into buffer
@loop:
	JSR GetByte		; get hex number from keyboard (byte)
	BCS @Return		; Branch if key was <Return>
	STA IN+1,X		; Store character in buffer (skip first length byte)
	INX			; Advance index into buffer
	CPX #$7E		; Buffer full?
	BNE @loop		; If not, go back and get more input
@Return:
	STX IN			; Store length of string
	LDA #0
	STA RETOK		; Clear flag to accept <Return> key
	STA CHAROK		; Clear flag to accept character input
	RTS			; Return

; Below came from
; http://www.6502.org/source/integers/hex2dec-more.htm
; Convert a 16 bit binary value to BCD
;
; This function converts a 16 bit binary value into a 24 bit BCD. It
; works by transferring one bit a time from the source and adding it
; into a BCD value that is being doubled on each iteration. As all the
; arithmetic is being done in BCD the result is a binary to decimal
; conversion. All conversions take 915 clock cycles.
;
; See BINBCD8 for more details of its operation.
;
; Andrew Jacobs, 28-Feb-2004
BINBCD16:    SED		; Switch to decimal mode
	LDA #0			; Ensure the result is clear
	STA BCD+0
	STA BCD+1
	STA BCD+2
	LDX #16			; The number of source bits
CNVBIT: ASL BIN+0		; Shift out one bit
	ROL BIN+1
	LDA BCD+0		; And add into result
	ADC BCD+0
	STA BCD+0
	LDA BCD+1		; propagating any carry
	ADC BCD+1
	STA BCD+1
	LDA BCD+2		; ... thru whole result
	ADC BCD+2
	STA BCD+2
	DEX			; And repeat for next bit
	BNE CNVBIT
	CLD			; Back to binary
	RTS			; All Done.

; Display processor flags
; Based on code at http://6502org.wikidot.com/software-output-flags

OUTP:
	LDA SAVE_P
P1:	LDX #7
@1:	ASL
	PHA
	LDA @3,X
	BCS @2
	ORA #%00100000		    ; Toggle letter case
@2:	JSR PUTCHR
	PLA
	DEX
	BPL @1
	RTS
@3: .byte "CZIDB-VN"

; Clears screen.
; Registers changed: none
ClearScreen:
	JMP CLRSCR

; Determines if BASIC ROM is present.
; Returns in A 1 if present, 0 if not.
; Looks for the first three bytes of ROM.
; It is unlikely but it could possibly not be present (e.g. when running in an Emulator)
BASICPresent:
	LDA BASIC		; First firmware byte
	CMP #$4C		; Should contain $4C
	BNE @NoBasic
	LDA BASIC+1		; Second firmware byte
	CMP #$B0		; Should contain $B0
	BNE @NoBasic
	LDA BASIC+2		; Third firmware byte
	CMP #$E2		; Should contain $E2
	BNE @NoBasic
	LDA #1
	RTS
@NoBasic:
	LDA #0
	RTS

; Strings

WelcomeMessage:
	.byte CR,"BENDER-I Computer Monitor",CR,0

PromptString:
	.asciiz "> "

InvalidCommand:
	.byte "Invalid command. Press <F1> for help", CR, 0

; Help string.
HelpString:
	.byte CR
	.byte "Assemble    A <address>", CR
	.byte "Breakpoint  B <n or ?> <address>", CR
	.byte "Copy        C <start> <end> <dest>", CR
	.byte "Dump        D <start>", CR
	.byte "Fill        F <start> <end> <data>...", CR
	.byte "Go          G <address>", CR
	.byte "Hex to dec  H <address>", CR
	.byte "BASIC       I", CR
	.byte "Checksum    K <start> <end>",CR
	.byte "Clr screen  L", CR
	.byte "Sound test  M", CR
	.byte "Info        N", CR
	.byte "Options     O", CR
	.byte "Registers   R", CR
	.byte "Search      S <start> <end> <data>...", CR
	.byte "Test        T <start> <end>", CR
	.byte "Unassemble  U <start>", CR
	.byte "Verify      V <start> <end> <dest>", CR
	.byte "Write       : <address> <data>...", CR
	.byte "Math        = <address> +/- <address>", CR
	.byte "Trace       .", CR
	.byte "Help        <F1>", CR
	.byte "Reboot      <F12>", CR
	.byte 0

ContinueString:
	.asciiz "  <Space> to continue, <ESC> to stop"

InvalidRange:
	.byte "Error: start must be <= end", CR, 0

NotFound:
	.byte "Not found", CR, 0

Found:
	.asciiz "Found at: "

MismatchString:
	.asciiz "Mismatch: "

TestString1:
	.asciiz "Testing memory from $"

TestString2:
	.asciiz " to $"

TestString3:
	.byte CR,"Press any key to stop", CR, 0

VNotRAMString:
  .byte "BRK vector not in RAM!", CR, 0

BNotRAMString:
  .byte "Breakpoint not in RAM!", CR, 0

NOBPString:
  .byte "Breakpoint not set!", CR, 0

IntString:
  .byte "Interrupt ?", CR, 0

UnknownBPString:
  .asciiz "Breakpoint ? at $"

KnownBPString1:
  .asciiz "Breakpoint "

KnownBPString2:
  .asciiz " at $"

ReadString:
  .byte " Read: ", 0

OptionsString:
  .byte "Display options", CR, 0

BorderColorString:
  .byte "Border color     : ", 0

BackgroundColorString:
  .byte "Background color : ", 0

ForegroundColorString:
  .byte "Foreground color : ", 0

InvalidInstructionString:
  .byte "Invalid instruction", 0

InvalidOperandString:
  .byte "Invalid operand", 0

InvalidAddressingModeString:
  .byte "Invalid addressing mode", 0

BranchOutOfRangeString:
  .byte "Relative branch out of range", 0

UnableToWriteString:
  .byte "Unable to write to $", 0

NoBASICString:
  .byte "BASIC not found!", CR, 0

CPUString:
	.asciiz "         CPU type: "

Type6502String:
	.asciiz "6502"

Type65C02String:
	.asciiz "65C02"

Type65816String:
	.asciiz "65816"

ResetVectorString:
	.asciiz "     RESET vector: $"

IRQVectorString:
	.asciiz "   IRQ/BRK vector: $"

NMIVectorString:
	.asciiz "       NMI vector: $"

PresentString:
	.asciiz "present"

NotString:
	.asciiz "not "

BASICString:
	.asciiz "        BASIC ROM: "

RAMString:
	.asciiz "RAM detected from: $0000 to "

  .include "disasm.s"
  .include "miniasm.s"
  .include "trace.s"
  .include "info.s"
  .include "memtest4.s"
  .include "sound.s"

; Non-Page Zero Variables. Note: These must be in RAM. Use a .org
; below corresponding to RAM if the program is linked into ROM.
; .org $1000

IN:	  .res 127		; Input buffer
T2:	  .res 1		; Temp variable 2
RETOK:	  .res 1		; Sets whether <Return> key is accepted in some input routines
BIN:	  .res 1		; Holds binary value low byte
BINH:	  .res 1		; Holds binary value high byte
BCD:	  .res 3		; Holds BCD decimal number (3 bytes)
LZ:	  .res 1		; Boolean for leading zero suppression
LAST:	  .res 1		; Boolean for leading zero suppression / indicates last byte
OPCODE:	  .res 1		; Instruction opcode
OP:	  .res 1		; Instruction type OP_*
AM:	  .res 1		; Addressing mode AM_*
LEN:	  .res 1		; Instruction length
REL:	  .res 2		; Relative addressing branch offset (2 bytes)
DEST:	  .res 2		; Relative address destination address (2 bytes)
START:	  .res 2		; Memory test - user entered start of memory range. Min is 8 (2 bytes)
END:	  .res 2		; Memory test - user entered end of memory range (2 bytes)
BPD:	  .res 4		; Instruction at breakpoint (1 byte * 4 breakpoints)
SAVE_A:	  .res 1		; Holds saved values of registers
SAVE_X:	  .res 1		; "
SAVE_Y:	  .res 1		; "
SAVE_S:	  .res 1		; "
SAVE_P:	  .res 1		; "
SAVE_PC:  .res 2		; "
NEXT_PC:  .res 2		; Value of PC after next instruction
THIS_S:	  .res 1		; Saved value of JMON's stack pointer
CHAROK:	  .res 1		; Set to 1 if okay to enter characters prefixed by '
CHARMODE: .res 1		; Set if currently entering in character (ASCII) mode
OCPU:	   .res 1		; CPU type for disassembly
MBIT:	   .res 1		; For 65816 disassembly, tracks state of M bit in P
XBIT:	   .res 1		; For 65816 disassembly, tracks state of X bit in P
MNEM:	   .res 3		; Hold three letter mnemonic string used by assembler
OPERAND:   .res 2		; Holds any operands for assembled instruction
TRACEINST: .res 8		; buffer holding traced instruction followed by a JMP and optionally another jump (Up to 8 bytes)
TAKEN:	   .res 1		; Flag indicating if a traced branch instruction was taken
