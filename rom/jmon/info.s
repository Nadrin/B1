; Information Routines
;
; Copyright (C) 2012-2014 by Jeff Tranter <tranter@pobox.com>
; B1 changes Copyright (C) 2015 by Michał Siejak <michal@siejak.pl>
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

; iNfo command
;
; Displays information such as: detected CPU type, clock speed,
;   range of RAM and ROM, detected peripheral cards. etc.
;
; Sample Output:
;
;	  CPU TYPE: 65C02
;RAM DETECTED FROM: $0000 TO $7FFF
;	NMI VECTOR: $0F00
;     RESET VECTOR: $FF00
;   IRQ/BRK VECTOR: $0100
;	 BASIC ROM: PRESENT

Info:
	JSR PUTCHR		; Echo command
	JSR PrintCR
	LDX #<CPUString		; Display CPU type
	LDY #>CPUString
	JSR PrintString
	JSR CPUType
	CMP #1
	BNE @Try2
	LDX #<Type6502String
	LDY #>Type6502String
	JMP @PrintCPU
@Try2:
	CMP #2
	BNE @Try3
	LDX #<Type65C02String
	LDY #>Type65C02String
	JMP @PrintCPU
@Try3:
	CMP #3
	BNE @Invalid
	LDX #<Type65816String
	LDY #>Type65816String

@PrintCPU:
	JSR PrintString
	JSR PrintCR

@Invalid:
	LDX #<RAMString	      ; Print range of RAM
	LDY #>RAMString
	JSR PrintString
	JSR PrintDollar
	JSR FindTopOfRAM
	JSR PrintAddress
	JSR PrintCR

	LDX #<NMIVectorString ; Print NMI vector address
	LDY #>NMIVectorString
	JSR PrintString
	LDX $FFFA
	LDY $FFFB
	JSR PrintAddress
	JSR PrintCR

	LDX #<ResetVectorString ; Print reset vector address
	LDY #>ResetVectorString
	JSR PrintString
	LDX $FFFC
	LDY $FFFD
	JSR PrintAddress
	JSR PrintCR

	LDX #<IRQVectorString ; Print IRQ/BRK vector address
	LDY #>IRQVectorString
	JSR PrintString
	LDX $FFFE
	LDY $FFFF
	JSR PrintAddress
	JSR PrintCR

	LDX #<BASICString
	LDY #>BASICString
	JSR PrintString
	JSR BASICPresent
	JSR PrintPresent
	JSR PrintCR
       
; Determine type of CPU. Returns result in A.
; 1 - 6502, 2 - 65C02, 3 - 65816.
; Algorithm taken from Western Design Center programming manual.

CPUType:
	SED	      ; Trick with decimal mode used
	LDA #$99      ; Set negative flag
	CLC
	ADC #$01      ; Add 1 to get new accumulator value of 0
	BMI O2	      ; 6502 does not clear negative flag so branch taken.

; 65C02 and 65816 clear negative flag in decimal mode

	CLC
	.p816	      ; Following Instruction is 65816
	XCE	      ; Valid on 65816, unimplemented NOP on 65C02
	BCC C02	      ; On 65C02 carry will still be clear and branch will be taken.
	XCE	      ; Switch back to emulation mode
	.p02	      ; Go back to 6502 assembler mode
	CLD
	LDA #3	      ; 65816
	RTS
C02:
	CLD
	LDA #2	      ; 65C02
	RTS
O2:
	CLD
	LDA #1	      ; 6502
	RTS

; Based on the value in A, displays "present" (1) or "not present" (0).

PrintPresent:
	CMP #0
	BNE @Present
	LDX #<NotString
	LDY #>NotString
	JSR PrintString
@Present:
	LDX #<PresentString
	LDY #>PresentString
	JMP PrintString

; Determines top of installed RAM while trying not to corrupt any other
; program including this one. We assume RAM starts at 0. Returns top
; RAM address in X (low), Y (high).

 LIMIT = $FFFF	      ; Highest address we want to test
 TOP   = $00	      ; Holds current highest addresse of RAM (two bytes)

FindTopOfRAM:

	LDA #<$0002	    ; Store $0002 in TOP (don't want to change TOP)
	STA TOP
	LDA #>$0002
	STA TOP+1

@Loop:
	LDY #0
	LDA (TOP),Y	    ; Read current contents of (TOP)
	TAX		    ; Save in register so we can later restore it
	LDA #0		    ; Write all zeroes to (TOP)
	STA (TOP),Y
	CMP (TOP),Y	    ; Does it read back?
	BNE @TopFound	    ; If not, top of memory found
	LDA #$FF	    ; Write all ones to (TOP)
	STA (TOP),Y
	CMP (TOP),Y	    ; Does it read back?
	BNE @TopFound	    ; If not, top of memory found
	LDA #$AA	    ; Write alternating bits to (TOP)
	STA (TOP),Y
	CMP (TOP),Y	    ; Does it read back?
	BNE @TopFound	    ; If not, top of memory found
	LDA #$55	    ; Write alternating bits to (TOP)
	STA (TOP),Y
	CMP (TOP),Y	    ; Does it read back?
	BNE @TopFound	    ; If not, top of memory found

	TXA		    ; Write original data back to (TOP)
	STA (TOP),Y

	LDA TOP		    ; Increment TOP (low,high)
	CLC
	ADC #1
	STA TOP
	LDA TOP+1
	ADC #0		    ; Add any carry
	STA TOP+1

;  Are we testing in the range of this code (i.e. the same 256 byte
;  page)? If so, need to skip over it because otherwise the memory
;  test will collide with the code being executed when writing to it.

	LDA TOP+1	    ; High byte of page
	CMP #>FindTopOfRAM  ; Same page as this code?
	BEQ @Skip
	CMP #>FindTopOfRAMEnd ; Same page as this code (code could cross two pages)
	BEQ @Skip
	BNE @NotUs
@Skip:
	INC TOP+1	    ; Skip over this page when testing

@NotUs:

	LDA TOP+1	    ; Did we reach LIMIT? (high byte)
	CMP #>LIMIT
	BNE @Loop	    ; If not, keep looping
	LDA TOP		    ; Did we reach LIMIT? (low byte)
	CMP #<LIMIT
	BNE @Loop	    ; If not, keep looping

@TopFound:
	TXA		    ; Write original data back to (TOP) just in case it is important
	STA (TOP),Y

FindTopOfRAMEnd:	    ; End of critical section we don't want to write to during testing

	LDA TOP		    ; Decrement TOP by 1 to get last RAM address
	SEC
	SBC #1
	STA TOP
	LDA TOP+1
	SBC #0		    ; Subtract any borrow
	STA TOP+1
  
	LDX TOP		    ; Set top of RAM as TOP (X-low Y-high)
	LDY TOP+1

	RTS		    ; Return

