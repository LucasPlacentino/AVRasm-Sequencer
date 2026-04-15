;
; AVRasm-Sequencer.asm
;
; PROJECT for Sensors and Microsystem Electronics
;
; Created: 15-04-26 12:01:41
; Author : lucasp
;

; ATmega328P
.INCLUDE "m328pdef.inc"

; .ORG
; .DEF
; .EQU
; RJMP

.def temp = r16 ; example: define alias "temp" for the register "r16"

; Timer1 reset value for overflow timing
; tcnt1 = 65536 - round(16MHz/(2*freq_sound))
; e.g: .equ TCNT1_RESET_880 = 47354  ;440Hz (880Hz because toggle) ? A
.equ TCNT1_RESET_C4  = 34958  ; 261.63 Hz
.equ TCNT1_RESET_CS4 = 36674  ; 277.18 Hz (C#)
.equ TCNT1_RESET_D4  = 38294  ; 293.66 Hz
.equ TCNT1_RESET_DS4 = 39823  ; 311.13 Hz (D#)
.equ TCNT1_RESET_E4  = 41267  ; 329.63 Hz
.equ TCNT1_RESET_F4  = 42628  ; 349.23 Hz
.equ TCNT1_RESET_FS4 = 43914  ; 369.99 Hz (F#)
.equ TCNT1_RESET_G4  = 45128  ; 392.00 Hz
.equ TCNT1_RESET_GS4 = 46273  ; 415.30 Hz (G#)
.equ TCNT1_RESET_A4  = 47354  ; 440.00 Hz
.equ TCNT1_RESET_AS4 = 48375  ; 466.16 Hz (A#)
.equ TCNT1_RESET_B4  = 49338  ; 493.88 Hz
.equ TCNT1_RESET_C5  = 50247  ; 523.25 Hz

; TODO: use CTC mdoe ? (clear timer on compare match)
; load value into OCR1A
; automatically resets timer and toggles pin (COM1A0 = 1) on the clock edge, it's more precise for slightly better sound
; buzzer needs to be connected to OC1A pin (PB1), it is thanks!!
; ocr1a = (16MHz / (2*N*freq_sound)) - 1
; where N is the prescaler (N=1 ?)
; --- OCR1A values for each note
.equ NOTE_C3  = 61156  ; 130.81 Hz
.equ NOTE_CS3 = 57723  ; 138.59 Hz (C#)
.equ NOTE_D3  = 54484  ; 146.83 Hz
.equ NOTE_DS3 = 51426  ; 155.56 Hz (D#)
.equ NOTE_E3  = 48540  ; 164.81 Hz
.equ NOTE_F3  = 45815  ; 174.61 Hz
.equ NOTE_FS3 = 43242  ; 185.00 Hz (F#)
.equ NOTE_G3  = 40815  ; 196.00 Hz
.equ NOTE_GS3 = 38525  ; 207.65 Hz (G#)
.equ NOTE_A3  = 36363  ; 220.00 Hz ---------
.equ NOTE_AS3 = 34322  ; 233.08 Hz (A#)
.equ NOTE_B3  = 32396  ; 246.94 Hz
; ---
.equ NOTE_C4  = 30577  ; 261.63 Hz
; or stop here ? to get only one octave but keep 3 buttons for other stuff ?
.equ NOTE_CS4 = 28861  ; 277.18 Hz (C#)
.equ NOTE_D4  = 27241  ; 293.66 Hz
.equ NOTE_DS4 = 25712  ; 311.13 Hz (D#)
; that's 16 notes, too much ?
.equ NOTE_E4  = 24269  ; 329.63 Hz
.equ NOTE_F4  = 22907  ; 349.23 Hz
.equ NOTE_FS4 = 21621  ; 369.99 Hz (F#)
.equ NOTE_G4  = 20407  ; 392.00 Hz
.equ NOTE_GS4 = 19262  ; 415.30 Hz (G#)
.equ NOTE_A4  = 18181  ; 440.00 Hz ---------
.equ NOTE_AS4 = 17160  ; 466.16 Hz (A#)
.equ NOTE_B4  = 16197  ; 493.88 Hz
; ---
.equ NOTE_C5  = 15288  ; 523.25 Hz

; example:
;Play_Note_C4:
;    ; CRITICAL: In AVR asm must write  HIGH byte of a 16-bit register first, then the LOW byte. The hardware latches it.
;    ldi temp, high(NOTE_C4)
;    sts OCR1AH, temp
;    ldi temp, low(NOTE_C4)
;    sts OCR1AL, temp
;
;    ; ; Ensure the timer is connected to the pin (un-mute)
;    ; ldi temp, (1<<COM1A0)
;    ; sts TCCR1A, temp
;    ret

; to play a sound, load the note index into a reg, then using a LUT to get the correct value to put in ocr1a ? rather than too many branches
; store this LUT in the flash mem
Notes_LUT:
	; .dw is define word
	.dw NOTE_C3, NOTE_CS3, NOTE_D3, NOTE_DS3
	.dw NOTE_E3, NOTE_F3, NOTE_FS3, NOTE_G3
	; TODO: ...
; 0x00 to 0x18
; 0xFF will be no sound

.dseg
.org SRAM_START ; (0x0100 ?)
Sequence: .byte 32 ; 32 bytes for the 32 steps
Step: .byte 1 ; keep traack of step number (0 to 31)
Tick_Counter: .byte 2 ; 16-bit counter for milliseconds
Tempo_Delay: .byte 2 ; 16-bit delay (in ms) based on BPM, kinda rounded
.cseg

; === play the note from r17 (input), byte is index of note, 0x00-0x18 or 0xFF ===
Play_Note:
	push r18
    push r19
    push r20
    push ZL ; aka r30
    push ZH ; aka r31
	; -- no note ?
	cpi r17, 0xFF
	breq Note_Mute

	; -- check if OOB memory location ? outside the lut
	cpi r17, 25 ; because 25 notes (or 0x19)
	brge End_Play_Note ; if index >= 25, skip to end
	; -- compute byte offset (word is 2 bytes, aka 16bits), 16 bit mult by 2:
	mov r18, r17 ; MOVe lut index to r18 (keep r17 intact)
    clr r19 ; CLeaR r19 for the high byte of the offset
    lsl r18 ; Logical Shift Left (mult r18 by 2) (MSB goes in the Carry Flag (C))
    rol r19 ; ROtate Left thrpugh carry r19, here just pulls the shifted MSB from r18 in the Carry Flag (to handle numbers > 127)

	; -- set up z pointer: r31(ZH)-r30(ZL) (flash mem is word-based, but `lpm` uses bytes for addresses, need to mult by 2 the note index of the lut)
	ldi ZL, low(Note_LUT * 2)
    ldi ZH, high(Note_LUT * 2)
	; -- add offset to z pointer
	add ZL, r18
    adc ZH, r19 ; ADd with Carry for the high byte (ZH = ZH + r19 + Carry_Flag from add above)
	; -- get data from lut in flash (little endian: low byte first, then high byte last)
	lpm r19, Z+ ; read low byte, then increment Z pointer
    lpm r20, Z ; read high byte

	; -- write val to timer 1 (high byte written first!)
	sts OCR1AH, r20
    sts OCR1AL, r19

	; ; optional ? unmute buzzer
	; ldi temp, (1<<COM1A0)
    ; sts TCCR1A, temp

	rjmp End_Play_Note

Note_Mute:
	; no note (mute)
	rcall Mute_Buzzer

End_Play_Note:
	pop ZH
    pop ZL
    pop r20
    pop r19
    pop r18

	ret
; ======

; === to mute: ===
Mute_Buzzer:
	; Disconnect the timer hardware from PB1 by clearing COM1A0
    ldi temp, 0x00
    sts TCCR1A, temp
    ; Force the pin LOW to prevent DC current from damaging the buzzer ?
    cbi PORTB, 1
	ret
; ======

; -- Use Timer 2 for the metronome
; 16MHz clock, prescaler at 64 => 250 000 ticks/sec
; for 1ms: (250000 / 1000) - 1 = 249
; let's use a "16th-note" step (whatever that means i'm not a musician)
; target delay is:
; 60000 / (BPM * 4) = Tempo_Delay


.equ LED_OUT2_DIR = DDRc
.equ LED_OUT2_BANK = PORTc
.equ LED_OUT2_IDX = 2 ; or PC2
.equ LED_OUT3_DIR = DDRc
.equ LED_OUT3_BANK = PORTc
.equ LED_OUT3_IDX = 3 ; or PC3

.equ BZ_OUT_DIR = DDRb
.equ BZ_OUT_BANK = PORTb
.equ BZ_OUT_IDX = 1
.equ BZ_OUT_PIN_TGL = PINb ; PINxn is PORTxn no need for DDRx for toggling
; we can just do SBI PINb,1 to toggle the buzzer pin

; .equ BZ_PORT = PORTb
; .equ BZ_TGL_PIN = PINb

.set SW_IN_DIR = DDRb
.set SW_IN_BANK = PORTb ;will be used for setting the pullup
.set SW_IN_IDX = 0
.set SW_IN_SENSE = PINb ; or directly PINb0 ?

;keypad
.equ KP_PIN = PINd
.equ KP_DDR = DDRd
.equ KP_PORT = PORTd
; see schematic:
; row1->4 = bit7->4 of PD
.equ ROW1 = 7
.equ ROW2 = 6
.equ ROW3 = 5
.equ ROW4 = 4
; col1->4 = bit3->0 of PD
.equ COL1 = 3
.equ COL2 = 2
.equ COL3 = 1
.equ COL4 = 0





; timer 0 and 2 are 8bit (up to 255), timer 1 is 16 bit (up to 65535)

.org 0x0000
	rjmp setup

; timer2 OVF
.org OC2Aaddr ; timer 2 overflow interrrupt vector ?
	rjmp ISR_Metronome


; use timer 1 for the buzzer sound notes

; === Setup sequence, runs once on startup ===
setup:
	sei ;enable interrupts

	;ldi R16, 1<<TOIE0 ; 0b001
	ldi temp, 0b1
	;sbi TIMSK0,TOIE0 ; cannot do that
	sts TIMSK0,temp ; enable timer 0 overflow interrupt ; store to SRAM (TIMSK0 is in Extended I/O space so in SRAM)

	;set timer 0 to normal mode
	ldi temp, 0b000 ; normal mode
	out TCCR0A,temp ; write to TCCR0A to set normal mode
	; set timer0 prescaler to 256 (0b100)
	;ldi R16, 1<<CS02 ; combine bits for prescaler 256
	ldi temp, 0b100 ; combine bits for prescaler 256
	out TCCR0B,temp ; write to TCCR0B to set prescaler

	; timer0 initial value to get 880 interrupts per second
	; 880Hz, f_clk prescaler 256 => 16MHz/256 => 184.977 = 185 initial value for timer to get 880 interrupts per second
	ldi R29, 185
	out TCNT0,R29

	; -- Configure TCCR1A
    ; COM1A1:0 = 01 -> Toggle OC1A on Compare Match
    ; WGM11:0  = 00 -> Lower bits for CTC Mode 4
    ldi temp, (1<<COM1A0)
    sts TCCR1A, temp
	; --- Configure TCCR1B
    ; WGM13:2 = 01 -> Upper bits for CTC Mode 4 (WGM = 0100)
    ; CS12:0  = 001 -> Prescaler = 1 (starts the timer)
    ldi temp, (1<<WGM12) | (1<<CS10)
    sts TCCR1B, temp

	;set pins

	;;sw input
	;cbi SW_IN_DIR,SW_IN_IDX ;clear bit i/o reg ;set dir of pin to 0 meaning input
	;sbi SW_IN_BANK,SW_IN_IDX ;set bit i/o reg ;set pullup of pin to enabled

	;buzzer output
	sbi BZ_OUT_DIR,BZ_OUT_IDX ;set buzzer out pin dir to output(1)
	cbi BZ_OUT_BANK,BZ_OUT_IDX ;clear buzzer to off

	;led output
	sbi LED_OUT2_DIR,LED_OUT2_IDX ;set led2 out pin dir to output(1)
	cbi LED_OUT2_BANK,LED_OUT2_IDX ;clear led2 to off
	sbi LED_OUT3_DIR,LED_OUT3_IDX ;set led3 out pin dir to output(1)
	cbi LED_OUT3_BANK,LED_OUT3_IDX ;clear led3 to off

	rjmp loop
; ======

; === infinite loop sequence ===
loop:

	rjmp kp_polling_1 ; ?

    rjmp loop
; ======

; === Metronome's ISR ===
ISR_Metronome:
	push temp
    push r17
    push ZL
    push ZH
    in temp, SREG
    push temp

	; ...

	End_Metronome_ISR:
    ; -- restore
    pop temp
    out SREG, temp
    pop ZH
    pop ZL
    pop r17
    pop temp
    reti
; ======


LED2ON:
	; LOW enable
	cbi LED_OUT2_BANK,LED_OUT2_IDX ;set bit of led to high
	ret
LED2OFF:
	sbi LED_OUT2_BANK,LED_OUT2_IDX ;set bit of led to low
	ret
LED3ON:
	; LOW enable
	cbi LED_OUT3_BANK,LED_OUT3_IDX ;set bit of led to high
	ret
LED3OFF:
	sbi LED_OUT3_BANK,LED_OUT3_IDX ;set bit of led to low
	ret
;BUZON:
;	ldi R16, 0b1
;	sts TIMSK0,R16 ; enable timer 0 overflow interrupt
;	ret
;BUZOFF:
;	ldi R16, 0b0
;	sts TIMSK0,R16 ; disable timer 0 overflow interrupt
;	ret



; making this a macro can make it more elegant
;KP_POLLING_2:
.macro KP_POLLING_2
	; careful: need to first modify PORT reg before modifying DDR reg.
	; rows as inputs:
	ldi temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
	out KP_PORT,temp ; bitmask to keypad port for rows
	; cols as outputs:
	ldi temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
	out KP_DDR,temp     ; bitmask to keypad port dir for cols

	nop ; No operation because "Add NOP when changing output connected to an input" slide 8 ("Bits in PINx register are always one cycle behind", synchronizer: PIN reg 1 clk-cycle late)
	; now we can read PIN reg

	;ldi row,0x0 ; default nothing pressed
	sbis KP_PIN,ROW1
	; rcall or rjmp to colY row X=1
	;ldi row,0x1
	rjmp @0 ; rjmp to first arg of macro

	sbis KP_PIN,ROW2
	; rcall or rjmp to colY row X=2
	;ldi row,0x2
	rjmp @1 ; rjmp to second arg of macro

	sbis KP_PIN,ROW3
	; rcall or rjmp to colY row X=3
	;ldi row,0x3
	rjmp @2 ; rjmp to third arg of macro

	sbis KP_PIN,ROW4
	; rcall or rjmp to colY row X=4
	;ldi row,0x4
	rjmp @3 ; rjmp to fourth arg of macro

	rjmp no_kp_pressed

	;ret
.endmacro

; this does the "2-step method" switching for the keypad
; - config all rows output, set them LOW
; - config all cols input, check which low
;	- the col y that is low has a btn pressed => col num Y
;	- config all rows input, all cols output
;	- => careful transition, intermediate pin states ! context switching
;	- set all cols to LOW, check row pins
;		- if all rows HIGH => btn release, exit
;		- if row x is LOW => btn pressed in Y col => row num X
;		- => btn pressed is row-X and col-Y
; - if no col is low (=all high) no btn is pressed, exit
kp_polling_1:
	; careful: need to first modify PORT reg before modifying DDR reg.
	; cols as inputs:
	ldi temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
	out KP_PORT,temp ; bitmask to keypad port for cols
	; rows as outputs set LOW:
	ldi temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
	out KP_DDR,temp ; bitmask to keypad port dir for rows

	nop ; No operation because "Add NOP when changing output connected to an input" slide 8 ("Bits in PINx register are always one cycle behind", synchronizer: PIN reg 1 clk-cycle late)
	; now we can read PIN reg

	sbis KP_PIN,COL1
	; rcall or rjmp to KP_POLLING_2 as col Y=1 or set a reg to some value?
	;ldi col,0x1
	rjmp col1pressed

	sbis KP_PIN,COL2
	; rcall or rjmp to KP_POLLING_2 as col Y=2
	;ldi col,0x2
	rjmp col2pressed

	sbis KP_PIN,COL3
	; rcall or rjmp to KP_POLLING_2 as col Y=3
	;ldi col,0x3
	rjmp col3pressed

	sbis KP_PIN,COL4
	; rcall or rjmp to KP_POLLING_2 as col Y=4
	;ldi col,0x4
	rjmp col4pressed

	; nothing was pressed
	rjmp no_kp_pressed
	;ret

no_kp_pressed:
	; do something/nothing ?
	rjmp loop

col1pressed:
	; col Y=1
	;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
	KP_POLLING_2 col1row1,col1row2,col1row3,col1row4 ; macro with args to rjmp to corresponding label
	; don't happen:
	rjmp loop
col2pressed:
	;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
	KP_POLLING_2 col2row1,col2row2,col2row3,col2row4 ; macro with args to rjmp to corresponding label
	; don't happen:
	rjmp loop
col3pressed:
	;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
	KP_POLLING_2 col3row1,col3row2,col3row3,col3row4 ; macro with args to rjmp to corresponding label
	; don't happen:
	rjmp loop
col4pressed:
	;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
	KP_POLLING_2 col4row1,col4row2,col4row3,col4row4 ; macro with args to rjmp to corresponding label
	; don't happen:
	rjmp loop

; --- COL 1 ---
col1row1:
	; do something
	rjmp loop
col1row2:
	; do something
	rjmp loop
col1row3:
	; do something
	rjmp loop
col1row4:
	; do something
	rjmp loop

; --- COL 2 ---
col2row1:
	; do something
	rjmp loop
col2row2:
	; do something
	rjmp loop
col2row3:
	; do something
	rjmp loop
col2row4:
	; do something
	rjmp loop

; --- COL 3 ---
col3row1:
	; do something
	rjmp loop
col3row2:
	; do something
	rjmp loop
col3row3:
	; do something
	rjmp loop
col3row4:
	; do something
	rjmp loop

; --- COL 4 ---
col4row1:
	; do something
	rjmp loop
col4row2:
	; do something
	rjmp loop
col4row3:
	; do something
	rjmp loop
col4row4:
	; do something
	rjmp loop


