; B1 BIOS (interrupt service routines)
; (c) 2015 Michal Siejak
; Licensed under MIT opensource license

; Reset interrupt ISR
; Performs early-boot initialization.
ISR_RESET:
	LDX #$FF		; Initialize CPU stack
	TXS
	JSR INIT		; Initialize BIOS
	JSR CLRSCR
	LDA #10			; Sleep for 1/10th of a second
	JSR WAIT
	LDA #5			; Beep!
	LDX #40
	JSR BEEP
	JMP $C400		; Jump to monitor code

; Non-maskable interrupt ISR
; Decrements raster interrupt based timer.
ISR_NMI:
	PHA			; Save A
	LDA TIMER		; Load current timer value
	BEQ @Done		; Decrement if non-zero
	DEC TIMER
@Done:
	PLA			; Restore A and return
	RTI

; Maskable interrupt ISR
ISR_IRQ:
	RTI

; Interrupt vectors
	.segment "VECTORS"
	.org $FFFA

	.word ISR_NMI
	.word ISR_RESET
	.word ISR_IRQ
