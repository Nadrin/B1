; B1 Sound Test
;
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

SoundTest:
	PHP				; Save CPU flags, A register.
	PHA

	JSR PUTCHR			; Echo command

	LDX #<WaveSelectString		; Print select string
	LDY #>WaveSelectString
	JSR PrintString
@ReadWave:
	JSR GETCHR			; Get wave type, give up on ESC
	CMP #ESC
	BEQ @Return
	CMP #'1'
	BEQ @WaveSquare
	CMP #'2'
	BEQ @WaveSine
	BNE @ReadWave

@WaveSquare:
	JSR PUTCHR			; Echo wave type
	LDA #0				; Set note offset
	STA T2
	LDA #$10			; Set square wave in audio control
	JMP @PlaySound

@WaveSine:
	JSR PUTCHR			; Echo wave type
	LDA #4				; Set note offset
	STA T2
	LDA #$20			; Set sine wave in audio control

@PlaySound:
	LDX #<SoundTestExitString	; Print help string
	LDY #>SoundTestExitString
	JSR PrintString

	STA AUDCTL			; Initialize audio control

@SoundLoop:
	LDA KBDCTL
	AND #%11000000
	BMI @KeyReleased
	BEQ @SoundLoop

	LDA KBDDAT			; Get actual key data
	CMP #ESC			; Return on ESC
	BEQ @Return

	CMP #F1				; Accept only F keys
	BMI @SoundLoop
	CMP #F12+1
	BPL @SoundLoop

	SEC				; Compute note index
	SBC #F1
	CLC
	ADC T2
	ASL
	ASL
	STA AUDFRQ
	LDA AUDCTL
	ORA #$0F
	STA AUDCTL
	JMP @SoundLoop

@KeyReleased:
	LDA KBDDAT			; Clear keyboard buffer
	LDA AUDCTL			; Set volume to 0
	AND #$F0
	STA AUDCTL
	JMP @SoundLoop

@Return:
	LDA #$0F			; Reset audio control
	STA AUDCTL

	PLA				; Restore CPU flags, registers
	PLP
	JMP PrintCR

WaveSelectString:
	.byte CR,"Select wave type (1=Square, 2=Sine) ",0

SoundTestExitString:
	.byte CR,"Press keys <F1>-<F12>, <ESC> to exit. ",0
