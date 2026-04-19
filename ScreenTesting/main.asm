;
; ScreenTesting.asm
;
; Created: 19-04-26 17:33:13
; Author : lucasp
;


; ATmega328P
.INCLUDE "m328pdef.inc"

.def temp = r16 ; example: define alias "temp" for the register "r16"

; SCREEN configuration constants
.equ SCREEN_D = DDRB ; Define Data Direction Register for Port B
.equ SCREEN_P = PORTB ; Define Output Register for Port B
.equ SCREEN_SENSE = PINB ; Define Input Register for Port B
.equ SCREEN_DATA = 3 ; Define Data line (SDI) on Pin PB3
.equ SCREEN_CLK = 5 ; Define Clock line on Pin PB5
; Note: Pin PB4 is used for the latch sequence (accessed via SCREEN_SENSE)

.MACRO shiftReg
    sbi SCREEN_P, SCREEN_DATA ; Set the data line HIGH
    sbrs @0, @1 ; Test bit @1 in register @0; skip next instruction if set
    cbi SCREEN_P, SCREEN_DATA ; Otherwise, set the data line LOW
    sbi SCREEN_SENSE, SCREEN_CLK ; Generate a rising edge: set the clock line HIGH
    sbi SCREEN_SENSE, SCREEN_CLK ; (Keep the clock line high to ensure proper timing)
.ENDMACRO

.dseg ; define data segment for SRAM
.org SRAM_START ; (0x0100 ?)
Sequence: .byte 32 ; 32 bytes for the 32 steps
Step: .byte 1 ; keep traack of step number (0 to 31)
Tick_Counter: .byte 2 ; 16bit counter for milliseconds
Tempo_Delay: .byte 2 ; 16bit delay (in ms) based on BPM, kinda rounded (sufficiently precise)
Current_BPM: .byte 1 ; store current BPM (value between 60 and 200)
Is_Playing: .byte 1 ; boolean to track if the sequencer is currently playing or paused
Prev_JS_Click: .byte 1 ; store previous joystick click state (for edge detection)
Prev_JS_Down: .byte 1 ; store previous joystick down state (for edge detection)
Prev_JS_Up: .byte 1 ; store previous joystick up state (for edge detection)
Prev_JS_Left: .byte 1 ; store previous joystick left state (for edge detection)
Prev_JS_Right: .byte 1 ; store previous joystick right state (for edge detection)
.cseg

; timer 0 and 2 are 8bit (up to 255), timer 1 is 16 bit (up to 65535)

.org 0x0000
    rjmp setup

setup:
	; Configure PB3, PB4, and PB5 as outputs and initialize their state
    ldi r17, (1<<3)|(1<<4)|(1<<5)    ; Load mask to set bits 3, 4, and 5 (for PB3, PB4, PB5)
    out SCREEN_D, r17              ; Set PB3, PB4, and PB5 as output
    out SCREEN_P, r17             ; Set initial state: set PB3, PB4, and PB5 HIGH (may be modified later)

    ; Initialize registers used for shifting
    ldi r22, 7           ; r22 is used as an offset for the character table
    ldi r21, 0b1000000   ; r21 holds the row control bits (7 bits; MSB set)

    ; Enable interrupts if needed (not used in this main loop version)
    sei

	rjmp loop

loop:
	rcall DrawDisplay ; Call the subroutine to display the symbol (shift out bits and latch)
    rcall Delay ; Call the delay subroutine to adjust refresh rate

	rjmp loop

DrawDisplay:
	; --- Process the character columns ---
    ldi ZL, low(CharacterA<<1)  ; Load low byte of the address
    ldi ZH, high(CharacterA<<1) ; Load high byte of the address
    dec r22                        ; Decrement offset register r22
    brpl not_reset                  ; If result is positive, branch to notreset
    ldi r22, 6                     ; Otherwise, reload r22 with 6
	not_reset:
    add ZL, r22                    ; Add offset in r22 to the low pointer (adjust character line selection)
    lpm r1, Z                      ; Load a byte from program memory into r1 (this byte represents one row of the character)

    ; Shift out the column bits:
    ; We perform 16 iterations, each shifting out 5 bits (16 * 5 = 80 bits in total)
    ldi r18, 16                    ; Load counter with 16 (number of iterations)
	ColLoop:
    shiftReg r1, 0                ; Call macro to shift out the MSB of r1 (column bit)
    shiftReg r1, 1                ; Shift out next bit (macro uses different bit position as parameter)
    shiftReg r1, 2                ; Shift out third bit
    shiftReg r1, 3                ; Shift out fourth bit
    shiftReg r1, 4                ; Shift out fifth bit
    dec r18                       ; Decrement loop counter
    brne ColLoop                  ; Repeat if counter is not zero

    ; After shifting column bits, generate two clock pulses on the data line:
    cbi SCREEN_P, SCREEN_DATA   ; Clear the data line (set to LOW)
    sbi SCREEN_SENSE, SCREEN_CLK     ; Set the clock line HIGH (first pulse)
    sbi SCREEN_SENSE, SCREEN_CLK     ; Set the clock line HIGH again (second pulse)

    ; --- Process the row selection ---
    ; Shift out 8 bits for row selection
    shiftReg r21, 6                ; Shift out bit corresponding to position 6 of r21
    shiftReg r21, 5                ; Shift out bit at position 5
    shiftReg r21, 4                ; Shift out bit at position 4
    shiftReg r21, 3                ; Shift out bit at position 3
    shiftReg r21, 2                ; Shift out bit at position 2
    shiftReg r21, 1                ; Shift out bit at position 1
    shiftReg r21, 0                ; Shift out bit at position 0

    ; Update the row register: shift it right; if result is zero, reload initial value
    lsr r21                      ; Logical shift right on r21
    brne endDisplay              ; If result is nonzero, skip reload
    ldi r21, 0b1000000           ; Otherwise, reload r21 with initial row pattern (MSB set)

	endDisplay:
    ; --- Latch sequence ---
    ; Generate a rising edge on PB4 to transfer shifted data into the output registers
    sbi SCREEN_SENSE, 4            ; Set PB4 HIGH (latch active)
    ; (A small delay can be added here if necessary)
    sbi SCREEN_P, 4           ; Set PB4 LOW to complete the latch sequence (OE active low)

    ret ; Return from subroutine

; hella simple delay
Delay:
    LDI r16, 50                  ; Outer loop counter set to 50
DelayOuter:
    LDI r17, 250                 ; Inner loop counter set to 250
DelayInner:
    DEC r17                      ; Decrement inner loop counter
    BRNE DelayInner              ; Continue inner loop until r17 reaches 0
    DEC r16                      ; Decrement outer loop counter
    BRNE DelayOuter              ; Continue outer loop until r16 reaches 0
    RET


A_char:
    .db 0b00110, 0b01001, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0