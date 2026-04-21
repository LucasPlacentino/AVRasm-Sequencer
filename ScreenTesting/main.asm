;
; ScreenTesting.asm
;
; Created: 19-04-26 17:33:13
; Author : lucasp
;

/*
; ATmega328P
.INCLUDE "m328pdef.inc"

.def temp = r16 ; example: define alias "temp" for the register "r16"

; SCREEN configuration constants
.equ SCREEN_D = DDRb ; Define Data Direction Register for Port B
.equ SCREEN_P = PORTb ; Define Output Register for Port B
.equ SCREEN_SENSE = PINb ; Define Input Register for Port B
.equ SCREEN_DATA = 3 ; Define Data line (SDI) on Pin PB3
.equ SCREEN_CLK = 5 ; Define Clock line on Pin PB5
; Note: Pin PB4 is used for the latch sequence (accessed via SCREEN_SENSE)
*/

; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/*
; === SRAM ALLOCATION ===
.dseg
.org SRAM_START
Screen_Buffer: .byte 560            ; Unpacked buffer: 80 cols * 7 rows = 560 bytes
.cseg

.org 0x0000
    rjmp setup

.macro shiftBit
    sbi SCREEN_P, SCREEN_DATA ; Assume HIGH
    sbrs @0, @1 ; If bit @1 in register @0 is set, skip next line
    cbi SCREEN_P, SCREEN_DATA ; It was 0, so pull LOW
    sbi SCREEN_SENSE, SCREEN_CLK ; Toggle clock HIGH
    sbi SCREEN_SENSE, SCREEN_CLK ; Toggle clock LOW (hardware dependent pulse)
.endmacro

; ========================================================
; SETUP
; ========================================================
setup:
    ; 1. Initialize Stack Pointer (Good practice for subroutines)
    ldi temp, high(RAMEND)
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp

    ; 2. Configure Display Pins as Outputs (PB3, PB4, PB5)
    ldi temp, (1<<3)|(1<<4)|(1<<5)
    out SCREEN_D, temp
    out SCREEN_P, temp

    ; 3. Clear the Screen Buffer
    rcall Clear_Screen

    ; 4. Draw test pixels using Set_Pixel

    ; -- Top-Left Corner (0, 0)
    ldi r16, 0      ; X
    ldi r17, 0      ; Y
    ldi r18, 1      ; State (ON)
    rcall Set_Pixel

    ; -- Top-Right Corner (79, 0)
    ldi r16, 79
    ldi r17, 0
    ldi r18, 1
    rcall Set_Pixel

    ; -- Bottom-Left Corner (0, 6)
    ldi r16, 0
    ldi r17, 6
    ldi r18, 1
    rcall Set_Pixel

    ; -- Bottom-Right Corner (79, 6)
    ldi r16, 79
    ldi r17, 6
    ldi r18, 1
    rcall Set_Pixel

    ; -- Center Pixel (40, 3)
    ldi r16, 40
    ldi r17, 3
    ldi r18, 1
    rcall Set_Pixel

    rjmp loop

; ========================================================
; MAIN LOOP
; ========================================================
loop:
    ; Continuously push the SRAM buffer to the physical LEDs
    rcall Refresh_Screen
	rcall Delay
    rjmp loop


; ========================================================
; Set_Pixel Subroutine
; Input: r16 = X (0 to 79), r17 = Y (0 to 6), r18 = State (1/0)
; ========================================================
Set_Pixel:
    push r19

    ; Y * 80 using hardware multiplier
    ldi r19, 80
    mul r17, r19
    mov ZL, r0
    mov ZH, r1

    ; Add X coordinate
    clr r19
    add ZL, r16
    adc ZH, r19

    ; Add Base Address of Screen_Buffer
    subi ZL, low(-Screen_Buffer)
    sbci ZH, high(-Screen_Buffer)

    ; Write State
    st Z, r18

    pop r19
    ret

; ========================================================
; Clear_Screen Subroutine
; Fills all 560 bytes of the buffer with 0x00
; ========================================================
Clear_Screen:
    ldi ZL, low(Screen_Buffer)
    ldi ZH, high(Screen_Buffer)

    ldi XL, low(560)    ; Use X register pair as a 16-bit countdown timer
    ldi XH, high(560)
    clr temp            ; value to store (0)

Clear_Loop:
    st Z+, temp
    sbiw XL, 1          ; Subtract 1 from the 16-bit X register pair
    brne Clear_Loop     ; Loop until X hits exactly 0
    ret

; ========================================================
; Refresh_Screen ("GPU" Driver)
; Translates the 560-byte buffer into the hardware shift format
; ========================================================
Refresh_Screen:
    ldi ZL, low(Screen_Buffer)
    ldi ZH, high(Screen_Buffer)

    ldi r21, 0b01000000 ; Start with Row 1 (Bit 6)
    ldi r22, 7          ; We have 7 rows

Row_Loop:
    ldi r18, 80         ; 80 columns per row

Col_Loop:
    ld r1, Z+           ; Load pixel state from SRAM

    ; Shift out bit 0 (because unpacked buffer uses 0x01 or 0x00)
    sbi SCREEN_P, SCREEN_DATA
    sbrs r1, 0
    cbi SCREEN_P, SCREEN_DATA

    sbi SCREEN_SENSE, SCREEN_CLK
    sbi SCREEN_SENSE, SCREEN_CLK

    dec r18
    brne Col_Loop

    ; Clock pulses padding (from your original snippet)
    cbi SCREEN_P, SCREEN_DATA
    sbi SCREEN_SENSE, SCREEN_CLK
    sbi SCREEN_SENSE, SCREEN_CLK

    ; Shift out 8 Row Selection Bits
    shiftBit r21, 7
    shiftBit r21, 6
    shiftBit r21, 5
    shiftBit r21, 4
    shiftBit r21, 3
    shiftBit r21, 2
    shiftBit r21, 1
    shiftBit r21, 0

    ; Latch the Data
    sbi SCREEN_SENSE, 4
    sbi SCREEN_P, 4

    ; Advance to next row
    lsr r21
    dec r22
    brne Row_Loop

    ret



*/
; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

; -------------------------------
/*
.org 0x0000
    rjmp setup

.macro shiftReg
    sbi SCREEN_P, SCREEN_DATA ; Set the data line HIGH
    sbrs @0, @1 ; Test bit @1 in register @0; skip next instruction if set
    cbi SCREEN_P, SCREEN_DATA ; Otherwise, set the data line LOW
    sbi SCREEN_SENSE, SCREEN_CLK ; Generate a rising edge: set the clock line HIGH
    sbi SCREEN_SENSE, SCREEN_CLK ; (Keep the clock line high to ensure proper timing)
.endmacro

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
    ldi ZL, low(A_char<<1)  ; Load low byte of the address
    ldi ZH, high(A_char<<1) ; Load high byte of the address
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
    .db 0b00110, 0b01001, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0b0
E_char:
    .db 0b01111, 0b01000, 0b01000, 0b01110, 0b01000, 0b01000, 0b01111, 0b0
one_char:
    .db 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110, 0b0
two_char:
    .db 0b01110, 0b00001, 0b00001, 0b00110, 0b01000, 0b01000, 0b01111, 0b0
three_char:
    .db 0b01110, 0b00001, 0b00001, 0b00110, 0b00001, 0b00001, 0b01110, 0b0
four_char:
    .db 0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010, 0b0
five_char:
    .db 0b01111, 0b01000, 0b01000, 0b01110, 0b00001, 0b00001, 0b01110, 0b0
six_char:
    .db 0b00110, 0b01000, 0b01000, 0b01110, 0b01001, 0b01001, 0b00110, 0b0
seven_char:
    .db 0b01111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000, 0b0
eight_char:
    .db 0b00110, 0b01001, 0b01001, 0b00110, 0b01001, 0b01001, 0b00110, 0b0
nine_char:
    .db 0b00110, 0b01001, 0b01001, 0b00111, 0b00001, 0b00001, 0b01110, 0b0
zero_char: ; also O_char
    .db 0b00110, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b00110, 0b0

; ----------------------------------
*/



; ====================================
/*
.include "m328pdef.inc"

;------------
; CONSTANTS
;------------
; SCREEN configuration constants
.equ SCREEN_DDR      = DDRB         ; Define Data Direction Register for Port B
.equ SCREEN_PORT     = PORTB        ; Define Output Register for Port B
.equ SCREEN_PIN      = PINB         ; Define Input Register for Port B
.equ SCREEN_DATA     = 3            ; Define Data line (SDI) on Pin PB3
.equ SCREEN_CLK      = 5            ; Define Clock line on Pin PB5
; Note: Pin PB4 is used for the latch sequence (accessed via SCREEN_PIN)

; (The TCNT values are not used anymore because we no longer rely on interrupts)

;--------
; MACROS
;--------
.MACRO shiftReg
    SBI SCREEN_PORT, SCREEN_DATA   ; Set the data line HIGH
    SBRS @0, @1                    ; Test bit @1 in register @0; skip next instruction if set
    CBI SCREEN_PORT, SCREEN_DATA   ; Otherwise, set the data line LOW
    SBI SCREEN_PIN, SCREEN_CLK     ; Generate a rising edge: set the clock line HIGH
    SBI SCREEN_PIN, SCREEN_CLK     ; (Keep the clock line high to ensure proper timing)
.ENDMACRO

;-------
; CODE
;-------
.CSEG
.ORG 0x0000
    RJMP init                      ; Jump to initialization routine

init:
    ; Configure PB3, PB4, and PB5 as outputs and initialize their state
    LDI r17, (1<<3)|(1<<4)|(1<<5)    ; Load mask to set bits 3, 4, and 5 (for PB3, PB4, PB5)
    OUT SCREEN_DDR, r17              ; Set PB3, PB4, and PB5 as output
    OUT SCREEN_PORT, r17             ; Set initial state: set PB3, PB4, and PB5 HIGH (may be modified later)

    ; Initialize registers used for shifting
    LDI r22, 7           ; r22 is used as an offset for the character table
    LDI r21, 0b1000000   ; r21 holds the row control bits (7 bits; MSB set)

    ; Enable interrupts if needed (not used in this main loop version)
    SEI

    RJMP main            ; Jump to the main loop

main:
    rcall DisplaySymbol  ; Call the subroutine to display the symbol (shift out bits and latch)
    rcall Delay          ; Call the delay subroutine to adjust refresh rate
    RJMP main            ; Infinite loop: repeat display and delay

DisplaySymbol:
    ; --- 1. Manage Row Counter ---
    ; r22 tracks the current row being drawn (6 down to 0)
    DEC r22
    BRPL notreset
    LDI r22, 6
notreset:

    ; --- 2. Shift out 80 individual column bits ---
    LDI r18, 80                      ; Set column counter to 80
ColLoop:
    CBI SCREEN_PORT, SCREEN_DATA     ; Default state: Pixel OFF

    ; Check if we are on the correct rows for the square (Row 3 or 4, 0-indexed!)
    CPI r22, 3
    BREQ check_col
    CPI r22, 4
    BREQ check_col
    RJMP clock_pulse                 ; Not the right row, skip to clock

check_col:
    ; Check if we are on the correct columns for the square (Col 40 or 41)
    CPI r18, 40
    BREQ turn_on
    CPI r18, 41
    BREQ turn_on
    RJMP clock_pulse                 ; Not the right column, skip to clock

turn_on:
    SBI SCREEN_PORT, SCREEN_DATA     ; Coordinate matched! Turn Pixel ON

clock_pulse:
    ; Generate the clock pulse to push the bit into the shift register
    SBI SCREEN_PIN, SCREEN_CLK       ; Clock HIGH
    SBI SCREEN_PIN, SCREEN_CLK       ; Clock LOW (toggled back)

    DEC r18
    BRNE ColLoop                     ; Repeat for all 80 columns

    ; --- 3. Padding clocks (from your original logic) ---
    CBI SCREEN_PORT, SCREEN_DATA
    SBI SCREEN_PIN, SCREEN_CLK
    SBI SCREEN_PIN, SCREEN_CLK

    ; --- 4. Process the row selection ---
    shiftReg r21, 6
    shiftReg r21, 5
    shiftReg r21, 4
    shiftReg r21, 3
    shiftReg r21, 2
    shiftReg r21, 1
    shiftReg r21, 0

    ; --- 5. Update the row register ---
    LSR r21
    BRNE endDisplay
    LDI r21, 0b1000000

endDisplay:
    ; --- 6. Latch sequence ---
    SBI SCREEN_PIN, 4                ; Latch HIGH
    CBI SCREEN_PORT, 4               ; Latch LOW
    RET

;---------------------------------------------------------
; Subroutine: Delay
; Simple delay loop to adjust the refresh rate.
;---------------------------------------------------------
Delay:
    LDI r16, 50                  ; Outer loop counter set to 50
DelayOuter:
    LDI r17, 250                 ; Inner loop counter set to 250
DelayInner:
    DEC r17                      ; Decrement inner loop counter
    BRNE DelayInner              ; Continue inner loop until r17 reaches 0
    DEC r16                      ; Decrement outer loop counter
    BRNE DelayOuter              ; Continue outer loop until r16 reaches 0
    RET                          ; Return from Delay subroutine

;---------------------------------------------------------
; Character Definitions for "ALEXIS"
; Each character is defined by 8 bytes (7 bits used plus a terminating 0).
;---------------------------------------------------------
CharacterA:
    .db 0b00110, 0b01001, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0

CharacterBite:
    .db 0b11011, 0b11011, 0b01010, 0b01010, 0b01010, 0b01010, 0b01110, 0

CharacterL:
    .db 0b01000, 0b01000, 0b01000, 0b01000, 0b01000, 0b01000, 0b01111, 0

CharacterE:
    .db 0b01111, 0b01000, 0b01000, 0b01110, 0b01000, 0b01000, 0b01111, 0

CharacterX:
    .db 0b01001, 0b01001, 0b00110, 0b00110, 0b01001, 0b01001, 0b01001, 0

CharacterI:
    .db 0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110, 0

CharacterS:
    .db 0b01111, 0b01000, 0b01000, 0b01111, 0b00001, 0b00001, 0b01111, 0
*/
; ====================================






.include "m328pdef.inc"

;------------
; CONSTANTS
;------------
.equ SCREEN_DDR      = DDRB
.equ SCREEN_PORT     = PORTB
.equ SCREEN_PIN      = PINB
.equ SCREEN_DATA     = 3
.equ SCREEN_CLK      = 5

; === REGISTERS ===
.def temp     = r16  ; General purpose temporary register
.def px_x     = r20  ; Set_Pixel input: X coordinate (0 to 79)
.def px_y     = r21  ; Set_Pixel input: Y coordinate (0 to 6)
.def px_state = r22  ; Set_Pixel input: State (1=ON, 0=OFF)

;--------
; MACROS
;--------
.MACRO shiftBit
    SBI SCREEN_PORT, SCREEN_DATA   ; Assume HIGH
    SBRS @0, @1                    ; Skip if bit is set
    CBI SCREEN_PORT, SCREEN_DATA   ; Was 0, so set LOW
    SBI SCREEN_PIN, SCREEN_CLK     ; Toggle clock HIGH
    SBI SCREEN_PIN, SCREEN_CLK     ; Toggle clock LOW
.ENDMACRO

;---------------------------------------------------------
; SRAM ALLOCATION (The Unpacked Buffer)
; 80 columns * 7 rows = 560 bytes
;---------------------------------------------------------
.DSEG
.ORG SRAM_START
Screen_Buffer: .byte 560 ; entire screen buffer, 1 led to 1 byte
Active_Row: .byte 1 ; Tracks the current screen row (electrically, 0 to 6)

;-------
; CODE
;-------
.CSEG
.ORG 0x0000
    RJMP init
.ORG 0x0020
    RJMP ISR_Timer0_OVF_Screen ; Timer 0 Overflow Vector for the Screen Refresh

init:
    ; 1. Initialize Stack Pointer (Required for rcall/ret)
    LDI temp, high(RAMEND)
    OUT SPH, temp
    LDI temp, low(RAMEND)
    OUT SPL, temp

    ; 2. Configure Display Pins
    LDI temp, (1<<3)|(1<<4)|(1<<5)
    OUT SCREEN_DDR, temp
    OUT SCREEN_PORT, temp

	; --- Timer 0 Setup (Display Multiplexing) ---
    ; 1. Prescaler = 64
    LDI temp, (1<<CS01)|(1<<CS00)
    OUT TCCR0B, temp

    ; 2. Enable Timer 0 Overflow Interrupt
    LDI temp, (1<<TOIE0)
    STS TIMSK0, temp

    ; 3. Initialize Active_Row to 0
    CLR temp
    STS Active_Row, temp

    ; 3. Clear the SRAM Buffer to black (0)
    rcall Clear_Screen

    ; 4. Draw a 2x2 square in the middle using Set_Pixel
    ; Top-Left (40, 3)
    LDI px_x, 38      ; X
    LDI px_y, 3       ; Y
    LDI px_state, 1       ; State (1 = ON)
    rcall Set_Pixel

    ; Top-Right (41, 3)
    LDI px_x, 39
    LDI px_y, 3
    LDI px_state, 1
    rcall Set_Pixel

    ; Bottom-Left (40, 4)
    LDI px_x, 38
    LDI px_y, 4
    LDI px_state, 1
    rcall Set_Pixel

    ; Bottom-Right (41, 4)
    LDI px_x, 39
    LDI px_y, 4
    LDI px_state, 1
    rcall Set_Pixel

	; test
	ldi px_x, 5
	ldi px_y, 11
	ldi px_state, 1
	rcall Set_Pixel

	; test
	ldi px_x,0
	ldi px_y,0
	ldi px_state,1
	rcall Set_Pixel

	LDI px_y, 13          ; Constant Y coordinate
    LDI px_state, 1       ; State = ON
    LDI px_x, 0           ; Start X at 0
	Draw_Bottom_Line:
    rcall Set_Pixel       ; Draw the current pixel
    INC px_x              ; Move 1 pixel to the right
    CPI px_x, 32          ; Compare X with 32 (the limit)
    BRNE Draw_Bottom_Line ; If X is not 40, loop back and draw the next one

	LDI r17, 128     ; Load a test BPM
    rcall Draw_BPM   ; Watch the math happen

	sei
    RJMP main

main:
    ; Continuously push the SRAM buffer to the physical LEDs
    ;rcall Refresh_Screen
    ;rcall Delay
    RJMP main

;---------------------------------------------------------
; ISR: Timer 0 Overflow (Fires 976 times per second)
; Draws exactly ONE row of the 80x7 matrix per execution.
;---------------------------------------------------------
ISR_Timer0_OVF_Screen:
    ; --- 1. Protect Registers ---
    PUSH temp
    IN temp, SREG
    PUSH temp
    PUSH r0
    PUSH r1
    PUSH r18
    PUSH r19
    PUSH r21
    PUSH ZL
    PUSH ZH

    ; --- 2. Fetch the Current Row ---
    LDS r19, Active_Row

    ; --- 3. Calculate Memory Address (Z = Screen_Buffer + Row * 80) ---
    LDI r18, 80
    MUL r19, r18                ; Multiply Active_Row by 80
    MOV ZL, r0
    MOV ZH, r1

    CLR r18                     ; Clear r18 to use for carry math
    ADD ZL, r18                 ; (Adding 0 to use ADC on high byte if needed)
    ADC ZH, r18

    SUBI ZL, low(-Screen_Buffer)
    SBCI ZH, high(-Screen_Buffer)

    ; --- 4. Shift out the 80 Columns for this row ---
    LDI r18, 80
isr_ColLoop:
    LD r1, Z+
    CBI SCREEN_PORT, SCREEN_DATA
    SBRC r1, 0
    SBI SCREEN_PORT, SCREEN_DATA

    SBI SCREEN_PIN, SCREEN_CLK
    SBI SCREEN_PIN, SCREEN_CLK
    DEC r18
    BRNE isr_ColLoop

    ; Padding clocks
    CBI SCREEN_PORT, SCREEN_DATA
    SBI SCREEN_PIN, SCREEN_CLK
    SBI SCREEN_PIN, SCREEN_CLK

    ; --- 5. Calculate and Shift the Row Mask ---
    ; Row 0 = 0b1000000. We shift it right by the Active_Row value.
    LDI r21, 0b1000000
    MOV temp, r19               ; Copy Active_Row to temp
    TST temp
    BREQ skip_shift
shift_mask_loop:
    LSR r21
    DEC temp
    BRNE shift_mask_loop
skip_shift:

    shiftBit r21, 6
    shiftBit r21, 5
    shiftBit r21, 4
    shiftBit r21, 3
    shiftBit r21, 2
    shiftBit r21, 1
    shiftBit r21, 0

    ; --- 6. Latch the Data ---
    SBI SCREEN_PIN, 4
    CBI SCREEN_PORT, 4

    ; --- 7. Update Active_Row for the next interrupt ---
    INC r19
    CPI r19, 7
    BRNE save_row
    CLR r19                     ; Reset to row 0 if we hit 7
save_row:
    STS Active_Row, r19

    ; --- 8. Restore Registers and Exit ---
    POP ZH
    POP ZL
    POP r21
    POP r19
    POP r18
    POP r1
    POP r0
    POP temp
    OUT SREG, temp
    POP temp
    RETI

;---------------------------------------------------------
; Subroutine: Refresh_Screen (The Display Driver)
; Reads the 560 bytes from SRAM and shifts them out.
;---------------------------------------------------------
Refresh_Screen:
    LDI ZL, low(Screen_Buffer)
    LDI ZH, high(Screen_Buffer)

    LDI r21, 0b1000000          ; Start with Row mask
    LDI r22, 7                  ; 7 rows total

RowLoop:
    LDI r18, 80                 ; 80 columns per row

ColLoop:
    LD r1, Z+                   ; Read pixel state from SRAM

    CBI SCREEN_PORT, SCREEN_DATA; Default state: LOW
    SBRC r1, 0                  ; If bit 0 of SRAM byte is 1, skip next line
    SBI SCREEN_PORT, SCREEN_DATA; State was 1, set HIGH

    SBI SCREEN_PIN, SCREEN_CLK  ; Clock pulse
    SBI SCREEN_PIN, SCREEN_CLK

    DEC r18
    BRNE ColLoop

    ; Padding clocks
    CBI SCREEN_PORT, SCREEN_DATA
    SBI SCREEN_PIN, SCREEN_CLK
    SBI SCREEN_PIN, SCREEN_CLK

    ; Process the row selection (7 bits)
    shiftBit r21, 6
    shiftBit r21, 5
    shiftBit r21, 4
    shiftBit r21, 3
    shiftBit r21, 2
    shiftBit r21, 1
    shiftBit r21, 0

    ; Latch sequence
    SBI SCREEN_PIN, 4
    CBI SCREEN_PORT, 4

    ; Advance row mask and repeat
    LSR r21
    DEC r22
    BRNE RowLoop
    RET

;---------------------------------------------------------
; Subroutine: Set_Pixel
; Input: px_x (0-39), px_y (0-13), px_state (0 or 1)
; Visually: (0,0) is TOP-LEFT. (39,13) is BOTTOM-RIGHT.
;---------------------------------------------------------
Set_Pixel:
    PUSH r19
    PUSH px_x
    PUSH px_y
    PUSH ZL                     ; <--- PROTECT Z POINTER
    PUSH ZH
    PUSH r0                     ; <--- PROTECT MULTIPLIER REGISTERS
    PUSH r1

    ; TRANSLATION LAYER (Standard 40x14 -> Hardware 80x7)
    CPI px_y, 7
    BRSH bottom_half_logic

top_half_logic:
    LDI r19, 79
    SUB r19, px_x
    MOV px_x, r19
    LDI r19, 6
    SUB r19, px_y
    MOV px_y, r19
    RJMP calc_address

bottom_half_logic:
    LDI r19, 39
    SUB r19, px_x
    MOV px_x, r19
    LDI r19, 13
    SUB r19, px_y
    MOV px_y, r19

calc_address:
    ; MEMORY MAPPING (Index = Y * 80 + X)
    LDI r19, 80
    MUL px_y, r19
    MOV ZL, r0
    MOV ZH, r1

    CLR r19
    ADD ZL, px_x
    ADC ZH, r19

    SUBI ZL, low(-Screen_Buffer)
    SBCI ZH, high(-Screen_Buffer)

    ST Z, px_state

    POP r1                      ; <--- RESTORE MULTIPLIER REGISTERS
    POP r0
    POP ZH                      ; <--- RESTORE Z POINTER
    POP ZL
    POP px_y
    POP px_x
    POP r19
    RET

;---------------------------------------------------------
; Subroutine: Clear_Screen
; Writes 0x00 to all 560 bytes of the Screen Buffer
;---------------------------------------------------------
Clear_Screen:
    LDI ZL, low(Screen_Buffer)
    LDI ZH, high(Screen_Buffer)

    LDI XL, low(560)            ; 16-bit counter using X register
    LDI XH, high(560)
    CLR temp

clear_loop:
    ST Z+, temp
    SBIW X, 1
    BRNE clear_loop
    RET


;---------------------------------------------------------
; Subroutine: Draw_BPM
; Input: r17 (The current BPM, 60 to 200)
;---------------------------------------------------------
Draw_BPM:
    PUSH r23    ; Hundreds
    PUSH r24    ; Tens
    PUSH r25    ; Units
    PUSH r22    ; Digit to draw
    PUSH px_x
    PUSH px_y

    ; --- 1. Clear the 3x14 drawing area (avoid ghosting) ---
    LDI px_x, 37
clear_box_x:
    LDI px_y, 0
clear_box_y:
    LDI px_state, 0
    rcall Set_Pixel
    INC px_y
    CPI px_y, 14
    BRNE clear_box_y
    INC px_x
    CPI px_x, 40
    BRNE clear_box_x

    ; --- 2. Binary to BCD (Split into digits) ---
    CLR r23
    CLR r24
    MOV r25, r17
count_100:
    CPI r25, 100
    BRLO count_10
    SUBI r25, 100
    INC r23
    RJMP count_100
count_10:
    CPI r25, 10
    BRLO draw_digits
    SUBI r25, 10
    INC r24
    RJMP count_10

draw_digits:
    ; --- 3. Draw Hundreds Digit (Y = 0) ---
    TST r23
    BREQ skip_hundreds      ; Do not draw a leading zero for BPM < 100
    MOV r22, r23
    LDI px_x, 37
    LDI px_y, 0
    rcall Draw_Number_3x4
skip_hundreds:

    ; --- 4. Draw Tens Digit (Y = 5) ---
    MOV r22, r24
    LDI px_x, 37
    LDI px_y, 5
    rcall Draw_Number_3x4

    ; --- 5. Draw Units Digit (Y = 10) ---
    MOV r22, r25
    LDI px_x, 37
    LDI px_y, 10
    rcall Draw_Number_3x4

    POP px_y
    POP px_x
    POP r22
    POP r25
    POP r24
    POP r23
    RET

;---------------------------------------------------------
; Subroutine: Draw_Number_3x4
; Reads the Font table and draws it bit by bit
; Inputs: r22 (Digit 0-9), px_x, px_y
;---------------------------------------------------------
Draw_Number_3x4:
    PUSH ZL
    PUSH ZH
    PUSH r18
    PUSH r19
    PUSH px_x
    PUSH px_y

    ; Calculate Z = Font3x4 + (digit * 4)
    LDI ZL, low(Font3x4 * 2)
    LDI ZH, high(Font3x4 * 2)
    LDI r18, 4
    MUL r22, r18
    ADD ZL, r0
    ADC ZH, r1

    LDI r18, 4              ; 4 rows high
draw_row:
    LPM r19, Z+             ; Read the font row byte

    ; Left Pixel (Bit 2)
    LDI px_state, 0
    SBRC r19, 2
    LDI px_state, 1
    rcall Set_Pixel

    ; Mid Pixel (Bit 1)
    INC px_x
    LDI px_state, 0
    SBRC r19, 1
    LDI px_state, 1
    rcall Set_Pixel

    ; Right Pixel (Bit 0)
    INC px_x
    LDI px_state, 0
    SBRC r19, 0
    LDI px_state, 1
    rcall Set_Pixel

    ; Reset X and move down 1 row for Y
    DEC px_x
    DEC px_x
    INC px_y
    DEC r18
    BRNE draw_row

    POP px_y
    POP px_x
    POP r19
    POP r18
    POP ZH
    POP ZL
    RET

/*
;---------------------------------------------------------
; Subroutine: Draw_BPM
; Input: r17 (The current BPM, 60 to 200)
;---------------------------------------------------------
Draw_BPM:
    PUSH r23    ; Hundreds
    PUSH r24    ; Tens
    PUSH r25    ; Units
    PUSH r22    ; Digit to draw

    ; --- 1. Binary to BCD (Split into digits) ---
    CLR r23
    CLR r24
    MOV r25, r17
count_100:
    CPI r25, 100
    BRLO count_10
    SUBI r25, 100
    INC r23
    RJMP count_100
count_10:
    CPI r25, 10
    BRLO draw_digits
    SUBI r25, 10
    INC r24
    RJMP count_10

draw_digits:
    ; --- 2. Draw Tens Digit (Y = 4) ---
    MOV r22, r24
    LDI px_x, 35
    LDI px_y, 4
    rcall Draw_Number_3x5

    ; --- 3. Draw Units Digit (Y = 9) ---
    MOV r22, r25
    LDI px_x, 35
    LDI px_y, 9
    rcall Draw_Number_3x5

    ; --- 4. Draw Hundreds Digit (Y = 0 to 3) ---
    CPI r23, 1
    BREQ draw_bpm_one
    CPI r23, 2
    BREQ draw_bpm_two
    RJMP end_draw_bpm       ; If 0, draw nothing

draw_bpm_one:
    LDI px_x, 36            ; Draw a straight vertical line
    LDI px_state, 1
    LDI px_y, 0
    rcall Set_Pixel
    INC px_y
    rcall Set_Pixel
    INC px_y
    rcall Set_Pixel
    INC px_y
    rcall Set_Pixel
    RJMP end_draw_bpm

draw_bpm_two:
    LDI px_state, 1
    LDI px_x, 35
    LDI px_y, 0             ; Top bar: 111
    rcall Set_Pixel
    INC px_x
    rcall Set_Pixel
    INC px_x
    rcall Set_Pixel
    LDI px_y, 1             ; Right dot: 001
    rcall Set_Pixel
    LDI px_y, 2             ; Middle dot: 010
    DEC px_x
    rcall Set_Pixel
    LDI px_y, 3             ; Bottom bar: 111
    rcall Set_Pixel
    INC px_x
    rcall Set_Pixel
    DEC px_x
    DEC px_x
    rcall Set_Pixel

end_draw_bpm:
    POP r22
    POP r25
    POP r24
    POP r23
    RET

;---------------------------------------------------------
; Subroutine: Draw_Number_3x5
; Reads the Font table and draws it bit by bit
; Inputs: r22 (Digit 0-9), px_x, px_y
;---------------------------------------------------------
Draw_Number_3x5:
    PUSH ZL
    PUSH ZH
    PUSH r18
    PUSH r19
    PUSH px_x
    PUSH px_y

    ; Calculate Z = Font3x5 + (digit * 6)
    LDI ZL, low(Font3x5 * 2)
    LDI ZH, high(Font3x5 * 2)
    LDI r18, 6
    MUL r22, r18
    ADD ZL, r0
    ADC ZH, r1

    LDI r18, 5              ; 5 rows high
draw_row:
    LPM r19, Z+             ; Read the font row byte

    ; Left Pixel (Bit 2)
    LDI px_state, 0
    SBRC r19, 2
    LDI px_state, 1
    rcall Set_Pixel

    ; Mid Pixel (Bit 1)
    INC px_x
    LDI px_state, 0
    SBRC r19, 1
    LDI px_state, 1
    rcall Set_Pixel

    ; Right Pixel (Bit 0)
    INC px_x
    LDI px_state, 0
    SBRC r19, 0
    LDI px_state, 1
    rcall Set_Pixel

    ; Reset X and move to next Y row
    DEC px_x
    DEC px_x
    INC px_y
    DEC r18
    BRNE draw_row

    POP px_y
    POP px_x
    POP r19
    POP r18
    POP ZH
    POP ZL
    RET

;---------------------------------------------------------
; 3x5 Font Table for Numbers 0-9 (Padded to 6 bytes)
;---------------------------------------------------------
Font3x5:
    .db 0b111, 0b101, 0b101, 0b101, 0b111, 0  ; 0
    .db 0b010, 0b110, 0b010, 0b010, 0b111, 0  ; 1
    .db 0b111, 0b001, 0b111, 0b100, 0b111, 0  ; 2
    .db 0b111, 0b001, 0b111, 0b001, 0b111, 0  ; 3
    .db 0b101, 0b101, 0b111, 0b001, 0b001, 0  ; 4
    .db 0b111, 0b100, 0b111, 0b001, 0b111, 0  ; 5
    .db 0b111, 0b100, 0b111, 0b101, 0b111, 0  ; 6
    .db 0b111, 0b001, 0b010, 0b010, 0b010, 0  ; 7
    .db 0b111, 0b101, 0b111, 0b101, 0b111, 0  ; 8
    .db 0b111, 0b101, 0b111, 0b001, 0b111, 0  ; 9
*/

Font3x4: ; for hundredth digit of BPM
	.db 0b111, 0b101, 0b101, 0b111  ; 0
    .db 0b110, 0b010, 0b010, 0b111  ; 1
    .db 0b111, 0b001, 0b110, 0b111  ; 2
    .db 0b111, 0b010, 0b001, 0b111  ; 3
    .db 0b101, 0b101, 0b111, 0b001  ; 4
    .db 0b111, 0b100, 0b011, 0b111  ; 5
    .db 0b111, 0b100, 0b111, 0b111  ; 6
    .db 0b111, 0b001, 0b010, 0b010  ; 7
    .db 0b111, 0b101, 0b111, 0b111  ; 8
    .db 0b111, 0b101, 0b111, 0b001  ; 9
; 3x4 Font:
; ##
;  #
;  #
; ###

; ###
;   #
; ##
; ###

; ###
;  #
;   #
; ###

; # #
; # #
; ###
;   #

; ###
; #
;  ##
; ###

; ###
; #
; ###
; ###

; ###
;   #
;  #
;  #

; ###
; # #
; ###
; ###

; ###
; # #
; ###
;   #

; ###
; # #
; # #
; ###
