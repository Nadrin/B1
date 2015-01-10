; B1 BIOS
; (c) 2015 Michał Siejak
; Licensed under MIT opensource license

; Constants
	MAXCOL  = 40
	MAXROW  = 25
	BRCOLOR = $005B
	BGCOLOR = $005B
	FGCOLOR = $0FFF

	CR      = $0D
	BS      = $08
	DEFCUR  = $DC

; Hardware addreses
	KBDCTL = $FD00
	KBDDAT = $FD01

	RASINT = $FD03
	BRCOLL = $FD04
	BRCOLH = $FD05
	BGCOLL = $FD06
	BGCOLH = $FD07
	FGCOLL = $FD08
	FGCOLH = $FD09
	FRMPAG = $FD0A
	MAPPAG = $FD0B

	AUDCTL = $FD0C
	AUDFRQ = $FD0D

	VRAM   = $F000
	CMAP   = $F400

; Zero-page locations
	TEMP     = $FA
	VRAMOFF0 = $FC
	VRAMOFF1 = $FE
	
; BIOS JUMP table
	.segment "BIOSJMP"
	.org $FF00

	JMP INIT
	JMP GETCHR
	JMP PUTCHR
	JMP SCROLL
	JMP SETCOL
	JMP SETROW
	JMP SETCUR
	JMP CLRSCR
	JMP WAIT
	JMP BEEP

; BIOS code
	.segment "BIOS"
	.org $EC00

; Initialize system
; Arguments: none
; Modifies : A, X, Y
INIT:
	CLD			; Set CPU flags to known state
	CLI

	LDA #$01		; Enable keyboard shift translation
	STA KBDCTL

	LDA #$FF		; Disable raster interrupt
	STA RASINT

	LDA #<BRCOLOR		; Initialize VPU color registers
	STA BRCOLL
	LDA #>BRCOLOR
	STA BRCOLH
	LDA #<BGCOLOR
	STA BGCOLL
	LDA #>BGCOLOR
	STA BGCOLH
	LDA #<FGCOLOR
	STA FGCOLL
	LDA #>FGCOLOR
	STA FGCOLH

	LDA #>VRAM		; Initialize VPU page pointers
	STA FRMPAG
	LDA #>CMAP
	STA MAPPAG

	LDA #$0F		; Initialize SPU (flat wave, max volume)
	STA AUDCTL
	LDA #$00
	STA AUDFRQ

	LDA #0			; Initialize zero-page variables
	STA TEMP
	LDA #<VRAM
	STA VRAMOFF0+0
	STA VRAMOFF1+0
	LDA #>VRAM
	STA VRAMOFF0+1
	STA VRAMOFF1+1

	LDA #0			; Initialize TTY & timer counter
	STA TTYCOL
	STA TTYROW
	STA TIMER
	LDA #DEFCUR
	STA CURSOR

	LDA #0			; Zero CPU registers
	LDX #0
	LDY #0

	RTS

; Gets character from keyboard
; Arguments : none
; Modifies  : result in A
GETCHR:
	PHP			; Save CPU flags
@PollKey:
	LDA KBDCTL		; Load value at keyboard control register
	AND #$40		; Get vaue of bit 6 (key press)
	BEQ @PollKey		; Zero means no key, loop until we have any
	LDA KBDDAT		; Load actual key data
	PLP			; Restore CPU flags
	RTS

; Outputs character to the screen
; Arguments : Character in A
; Modifies  : none
PUTCHR:
	PHP			; Save CPU flags and A,Y registers
	PHA
	STA TEMP
	TYA
	PHA

	LDA #0
	LDY TTYCOL		; Load current TTY column
	STA (VRAMOFF0),Y	; Clear cursor

	LDA TEMP

	CMP #CR			; If character is CR, increment line
	BEQ @NextLine
	CMP #BS			; If character is BS, then erase, otherwise print
	BNE @PrintChar

	CPY #0			; If we're already on first column, do nothing
	BEQ @Done
	DEY			; Decrement TTY column
	STY TTYCOL
	LDA CURSOR		; Store cursor in VRAM if set
	BEQ @Done
	STA (VRAMOFF0),Y
	JMP @Done		; We're done

@PrintChar:
	STA (VRAMOFF0),Y	; Store character in VRAM, current column
	INY			; Increment TTY column
	CPY #MAXCOL		; If max column number reached increment line
	BEQ @NextLine

	STY TTYCOL		; Update TTY column

	LDA CURSOR		; Store cursor in VRAM if set
	BEQ @Done
	STA (VRAMOFF0),Y
	JMP @Done

@NextLine:
	LDY #0			; Set TTY column to 0
	STY TTYCOL
	LDY TTYROW		; Load and increment TTY row
	INY
	CPY #MAXROW		; If max row number reached scroll the screen
	BEQ SCROLL_PUTCHR

	STY TTYROW		; Update TTY row and add MAXCOL to VRAM pointer #1
	CLC			; ... so it points to current line
	LDA VRAMOFF0+0
	ADC #MAXCOL
	STA VRAMOFF0+0
	LDA VRAMOFF0+1
	ADC #0
	STA VRAMOFF0+1

@Done:
	PLA			; Restore CPU flags and A,Y registers
	TAY
	PLA
	PLP
	RTS

; Scroll the screen vertically by one line.
; Arguments : none
; Modifies  : none
SCROLL:
	PHP			; Save CPU flags and A,X,Y registers
	PHA
	TYA
	PHA

SCROLL_PUTCHR:			; Entry point for PUTCHR
	TXA
	PHA

	LDX #1			; Initialize X to 1. It will be source line number
				; ... for copying the screen line-by-line
	LDA #<VRAM		; Reset VRAM pointer #1 to the beginning of VRAM
	STA VRAMOFF0+0
	LDA #>VRAM
	STA VRAMOFF0+1

@CopyRows:
	CPX #MAXROW		; If source line reached maximum value clear last line
	BEQ @ClearLine

	CLC			; VRAMOFF1 = VRAMOFF0 + MAXCOL
	LDA VRAMOFF0+0
	ADC #MAXCOL
	STA VRAMOFF1+0
	LDA VRAMOFF0+1
	ADC #0
	STA VRAMOFF1+1

	LDY #0			; Initialize Y to current column number
@CopyCols:
	LDA (VRAMOFF1),Y	; Copy current row byte-by-byte from VRAMOFF1 to VRAMOFF0
	STA (VRAMOFF0),Y
	INY
	CPY #MAXCOL		; ... until maximum column reached
	BNE @CopyCols

	LDA VRAMOFF1+0		; VRAMOFF0 = VRAMOFF1
	STA VRAMOFF0+0
	LDA VRAMOFF1+1
	STA VRAMOFF0+1

	INX			; Increment current row
	JMP @CopyRows		; ... and loop

@ClearLine:
	LDY #0			; Y is current column
	LDA #0			; Clear with byte 0 (blank)

@ClearLineLoop:
	STA (VRAMOFF0),Y	; Byte-by-byte clear until max column reached
	INY
	CPY #MAXCOL
	BNE @ClearLineLoop

@Done:
	PLA
	TAX
	PLA
	TAY
	PLA
	PLP
	RTS

; Sets current TTY column
; Arguments : Column number in Y
; Modifies  : Carry set on error
SETCOL:
	PHP			; Save CPU flags
	CPY #MAXCOL		; Only set if value in Y is <MAXCOL
	BPL @Error
	
	PHA			; Save A,Y registers
	TYA
	PHA

	LDY TTYCOL		; Load current column in Y
	CPY #MAXCOL		; Clear cursor only if <MAXCOL
	BEQ @NoClear

	LDA CURSOR		; Clear cursor only if it is set
	BEQ @NoClear

	LDA #0
	STA (VRAMOFF0),Y

@NoClear:
	PLA			; Restore original value of Y
	TAY
	LDA CURSOR		; Place cursor in the new position
	STA (VRAMOFF0),Y
	STY TTYCOL		; Update TTY column
	
	PLA			; We're done
	PLP
	CLC
	RTS

@Error:
	PLP
	SEC
	RTS

; Sets current TTY row
; Arguments : Row number in X
; Modifies  : Carry set on error
SETROW:
	PHP			; Save CPU flags
	CPX #MAXROW		; Only set if value in X is <MAXROW
	BPL @Error

	PHA			; Save A,X,Y registers
	TXA
	PHA
	TYA
	PHA

	LDY TTYCOL		; Load current column in Y

	CPY #MAXCOL		; Clear cursor only if <MAXCOL
	BEQ @NoClearCursor

	LDA CURSOR		; Clear cursor only if it is set
	BEQ @NoClearCursor

	LDA #0
	STA (VRAMOFF0),Y

@NoClearCursor:
	STX TTYROW		; Update TTYROW

	LDA #<VRAM		; Reset VRAMOFF0 to row 0
	STA VRAMOFF0+0
	LDA #>VRAM
	STA VRAMOFF0+1

	CPX #0
@Loop:
	BEQ @LoopEnd		; If row number is zero, end loop

	CLC			; Add MAXCOL to VRAMOFF0 until
	LDA VRAMOFF0+0		; ... desired row is reached
	ADC #MAXCOL
	STA VRAMOFF0+0
	LDA VRAMOFF0+1
	ADC #0
	STA VRAMOFF0+1

	DEX			; Decrement row counter, loop
	JMP @Loop

@LoopEnd:
	CPY #MAXCOL		; Place cursor only if <MAXCOL
	BEQ @NoPlaceCursor
	LDA CURSOR		; Place cursor only if it is set
	BEQ @NoPlaceCursor
	STA (VRAMOFF0),Y

@NoPlaceCursor:
	PLA			; We're done
	TAY
	PLA
	TAX
	PLA
	PLP
	CLC
	RTS

@Error:
	PLP
	SEC
	RTS

; Sets current TTY cursor character
; Arguments : Character in A
; Modifies  : none
SETCUR:
	PHP			; Save CPU flags, register A
	PHA
	CMP CURSOR		; Only update cursor if it's different from one already set
	BEQ @Done

	STA CURSOR		; Update current cursor
	TYA			; Save Y register
	PHA

	LDA CURSOR		; Place new cursor on screen
	LDY TTYCOL
	CPY #MAXCOL		; only if current column is <MAXCOL
	BEQ @NoPlaceCursor
	STA (VRAMOFF0),Y
	
@NoPlaceCursor:
	PLA			; Restore Y register
	TAY

@Done:
	PLA
	PLP
	RTS

; Clears the screen
; Arguments : none
; Modifies  : none
CLRSCR:
	PHP			; Save CPU flags and registers
	PHA
	TXA
	PHA
	TYA
	PHA

	LDA #<VRAM		; Reset VRAMOFF0 and VRAMOFF1 to
	STA VRAMOFF0+0		; ... the beginning of VRAM
	STA VRAMOFF1+0
	LDA #>VRAM
	STA VRAMOFF0+1
	STA VRAMOFF1+1

	LDA #0			; Reset current TTY row and col
	STA TTYROW
	STA TTYCOL

	LDX #4			; Clear 4 256-byte memory segments
	LDY #0
@LoopSegment:
	STA (VRAMOFF1),Y
	INY
	BNE @LoopSegment

	INC VRAMOFF1+1		; Increment high-byte of VRAMOFF1 so
	DEX			; ... it points to the next segment
	BNE @LoopSegment

	LDA CURSOR
	STA (VRAMOFF0),Y	; Place cursor at top of the screen

	PLA			; Restore CPU flags and registers
	TAY
	PLA
	TAX
	PLA
	PLP
	RTS

; Delays execution until timer is zero.
; Arguments : Timer value in A
; Modifies  : None
WAIT:
	PHP			; Save CPU flags, A register
	PHA

	STA TIMER		; Set timer value
	LDA #$E8		; Enable raster interrupt on VBLANK
	STA RASINT
@Loop:
	LDA TIMER
	BNE @Loop		; Loop until timer is zero

	LDA #$FF		; Disable raster interrupt
	STA RASINT

	PLA			; Restore CPU flags and registers
	PLP
	RTS

; Delays execution and makes a sound
; Arguments : Timer value in A
;             Sound frequency in X
; Modifies  : Carry set on error
BEEP:
	PHP			; Save CPU flags
	CPX #64			; Check if frequency value is within bounds
	BPL @Error

	PHA			; Save A register
	LDA #$1F		; Set audio control register (square wave, max volume)
	STA AUDCTL
	STX AUDFRQ		; Set audio frequency register

	PLA
	JSR WAIT		; Wait until timer is zero

	PHA
	LDA #$0F		; Set audio control register (no sound)
	STA AUDCTL

	PLA			; Return, clear error
	PLP
	CLC
	RTS

@Error:
	PLP			; Return, set error
	SEC
	RTS

; Variables
TTYCOL: .res 1		; Current TTY column
TTYROW: .res 1		; Current TTY row
CURSOR: .res 1		; Cursor
TIMER:  .res 1		; Timer counter

; Interrupt service routines follow
	.include "isr.s"

