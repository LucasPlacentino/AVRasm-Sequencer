;
; display.asm :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

.include "m328pdef.inc"

;------------
; CONSTANTS
;------------
.equ DISPLAY_D      = DDRB
.equ DISPLAY_PORT     = PORTB
.equ DISPLAY_PIN      = PINB
.equ DISPLAY_DATA     = 3
.equ DISPLAY_CLK      = 5

; === REGISTERS ===
; .def temp = r16 ; already defined in main file
.def px_x = r20 ; Set_Pixel input: X coordinate (0 to 79)
.def px_y = r21 ; Set_Pixel input: Y coordinate (0 to 6)
.def px_state = r22 ; Set_Pixel input: State (1=ON, 0=OFF)

;--------
; MACROS
;--------
.MACRO shiftBit
    SBI DISPLAY_PORT, DISPLAY_DATA   ; Assume HIGH
    SBRS @0, @1                    ; Skip if bit is set
    CBI DISPLAY_PORT, DISPLAY_DATA   ; Was 0, so set LOW
    SBI DISPLAY_PIN, DISPLAY_CLK     ; Toggle clock HIGH
    SBI DISPLAY_PIN, DISPLAY_CLK     ; Toggle clock LOW
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
    OUT DISPLAY_D, temp
    OUT DISPLAY_PORT, temp

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
    CBI DISPLAY_PORT, DISPLAY_DATA
    SBRC r1, 0
    SBI DISPLAY_PORT, DISPLAY_DATA

    SBI DISPLAY_PIN, DISPLAY_CLK
    SBI DISPLAY_PIN, DISPLAY_CLK
    DEC r18
    BRNE isr_ColLoop

    ; Padding clocks
    CBI DISPLAY_PORT, DISPLAY_DATA
    SBI DISPLAY_PIN, DISPLAY_CLK
    SBI DISPLAY_PIN, DISPLAY_CLK

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
    SBI DISPLAY_PIN, 4
    CBI DISPLAY_PORT, 4

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

    CBI DISPLAY_PORT, DISPLAY_DATA; Default state: LOW
    SBRC r1, 0                  ; If bit 0 of SRAM byte is 1, skip next line
    SBI DISPLAY_PORT, DISPLAY_DATA; State was 1, set HIGH

    SBI DISPLAY_PIN, DISPLAY_CLK  ; Clock pulse
    SBI DISPLAY_PIN, DISPLAY_CLK

    DEC r18
    BRNE ColLoop

    ; Padding clocks
    CBI DISPLAY_PORT, DISPLAY_DATA
    SBI DISPLAY_PIN, DISPLAY_CLK
    SBI DISPLAY_PIN, DISPLAY_CLK

    ; Process the row selection (7 bits)
    shiftBit r21, 6
    shiftBit r21, 5
    shiftBit r21, 4
    shiftBit r21, 3
    shiftBit r21, 2
    shiftBit r21, 1
    shiftBit r21, 0

    ; Latch sequence
    SBI DISPLAY_PIN, 4
    CBI DISPLAY_PORT, 4

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
