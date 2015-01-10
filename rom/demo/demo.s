; B1 Demo Program
; (c) 2015 Michał Siejak
; Licensed under MIT opensource license

	.segment "DEMO"
	.org $C200

; Constants
	BARWIDTH = 32		; Width of the raster bar
	BARTOP   = 32		; Maximum top position
	BARBOT   = 168		; Maximum bottom position
	FRAMEPAG = $B0		; Frame page address
	TEXTPTR  = $B1B8	; Text pointer (determines position on screen)
	TEXTOFF  = 3		; Text horizontal offset
	FGCOLOR  = $04F4	; Foreground color

; Zero page locations
	TEMP     = $00		; Temporary variable
	VRAMPTR  = $01		; Frame page pointer
	BARSTART = $03		; Current raster bar position
	BARDIR   = $04		; Current raster bar direction
	BARPAL   = $05		; Start of color palette

; Initialization
INIT:
	PHP			; Save CPU flags and registers
	PHA
	TXA
	PHA
	TYA
	PHA

	LDX #10-1		; Save VPU & SPU state (10 bytes)
SAVESTATE:
	LDA $FD04-1,X
	STA VPUSTATE,X
	DEX
	BNE SAVESTATE

	LDA #<FGCOLOR		; Set foreground color
	STA $FD08
	LDA #>FGCOLOR
	STA $FD09

	LDA #$0F		; Initialize audio
	STA $FD0C

	LDA #BARTOP		; Initialize raster bar
	STA BARSTART
	LDA #1
	STA BARDIR

	LDX #BARWIDTH		; Initialize color palette
PALCOPY:
	LDA BARCOLORS,X
	STA BARPAL,X
	DEX
	BNE PALCOPY

	LDA #0			; Initialize frame address
	STA VRAMPTR
	LDA #FRAMEPAG
	STA VRAMPTR+1
	STA $FD0A

	LDA #0			; Clear the screen
	LDY #0
	LDX #4
CLRSEGMENT:
	STA (VRAMPTR),Y
	INY
	BNE CLRSEGMENT

	INC VRAMPTR+1
	DEX
	BNE CLRSEGMENT

	LDA #<TEXTPTR		; Set VRAM ptr to the line where our text should be
	STA VRAMPTR
	LDA #>TEXTPTR
	STA VRAMPTR+1

	LDX #0			; Print text to the screen
	LDY #TEXTOFF
PRINTLOOP:
	NOP
	LDA TEXT,X
	STA (VRAMPTR),Y
	INX
	INY
	CMP #0
	BNE PRINTLOOP

; Main demo loop
MAINLOOP:
	
	LDA #0			; Wait for the top of the screen and initialize
	JSR WAITRAS		; color registers
	STA $FD05
	STA $FD06
	STA $FD07
TOPBORDER:			; Draw top border
	LDA #0
	JSR GETRASRP
	CLC
	ADC #16
	TAX
	LDA BARPAL,X
	STA $FD04
	CPX #31
	BCC TOPBORDER

	LDA BARSTART		; Draw moving raster bar
	JSR WAITRAS
	TAY
RASTERBAR:
	TYA
	JSR GETRASRP
	TAX
	LDA BARPAL,X
	STA $FD05
	STA $FD07
	CPX #BARWIDTH
	BCC RASTERBAR

	LDA #216		; Draw bottom border
	JSR WAITRAS
	LDA #0
	STA $FD05
BOTBORDER:
	LDA #216
	JSR GETRASRP
	TAX
	LDA BARPAL,X
	STA $FD04
	CMP #15
	BCC BOTBORDER

	LDA BARSTART		; Increment raster bar position
	CLC
	ADC BARDIR
	STA BARSTART
	CMP #BARTOP		; Reverse direction if reached max top/bottom
	BEQ REVERSETOP
	CMP #BARBOT
	BEQ REVERSEBOT
	JMP MAKESOUND		; See if we should make a beep

REVERSETOP:
	LDA #1			; Start moving downwards
	STA BARDIR
	JMP MAKESOUND

REVERSEBOT:
	LDA #$FF		; Start moving upwards
	STA BARDIR

MAKESOUND:
	LDA BARSTART		; Make sound if we're near the top/bottom 
	CMP #BARTOP+3		; (3 lines offset)
	BCC BEEPTOP
	CMP #BARBOT-3
	BCS BEEPBOT

	LDA #$0F		; Set audio control to silence
	STA $FD0C
	JMP CHECKESC

BEEPTOP:
	LDA #$1F		; Beeping on top. Set a high note
	STA $FD0C
	LDA #50
	STA $FD0D
	JMP CHECKESC

BEEPBOT:
	LDA #$1F		; Beeping on bottom. Set a low note
	STA $FD0C
	LDA #30
	STA $FD0D

CHECKESC:
	LDA #%01000000		; Check if user pressed ESC
	BIT $FD00
	BEQ CONTINUE		; No key pressed at all, continue
	LDA $FD01
	CMP #$1B
	BNE CONTINUE		; Key pressed but it wasn't ESC, continue
	JMP QUIT		; ESC pressed, we should quit now

CONTINUE:
	JMP MAINLOOP

; Shutdown 
QUIT:
	LDX #9		; Restore VPU & SPU state (10 bytes)
LOADSTATE:
	LDA VPUSTATE,X
	STA $FD04-1,X
	DEX
	BNE LOADSTATE

	PLA		; Restore CPU flags and registers
	TAY
	PLA
	TAX
	PLA
	PLP
	RTS

; Wait for raster
WAITRAS:
	CMP $FD02
	BNE WAITRAS
	RTS

; Get raster relative position
GETRASRP:
	STA TEMP
	LDA $FD02
	SEC
	SBC TEMP
	RTS

; Variables
VPUSTATE:	.res 8	; Original VPU state
SPUSTATE:	.res 2  ; Original SPU state
TEXT:		.asciiz "BENDER-I can do demo effects! :-)"

; Raster bar color palette
BARCOLORS:	.byte	$00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
		.byte	$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00
