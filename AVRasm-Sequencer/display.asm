;
; display.asm :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

;--------
; MACROS
;--------
.macro shiftBit_macro
    sbi DISPLAY_PORT, DISPLAY_DATA_I
    sbrs @0, @1
    cbi DISPLAY_PORT, DISPLAY_DATA_I
    sbi DISPLAY_PIN, DISPLAY_CLK_I
    sbi DISPLAY_PIN, DISPLAY_CLK_I
.endmacro

Init_Display:

    ; 3. Initialize Active_Row to 0
    CLR temp
    STS Active_Row, temp

    ; 3. Clear the SRAM Buffer to black (0)
    rcall Clear_Screen

    ; ; FIXME: test
    ; ldi px_x, 5
    ; ldi px_y, 8
    ; ldi px_state, 1
    ; rcall Set_Pixel

    ; ; FIXME: test
    ; LDI px_y, 13          ; Constant Y coordinate
    ; LDI px_state, 1       ; State = ON
    ; LDI px_x, 0           ; Start X at 0
    ; Draw_Bottom_Line:
    ; rcall Set_Pixel       ; Draw the current pixel
    ; INC px_x              ; Move 1 pixel to the right
    ; CPI px_x, 32          ; Compare X with 32 (the limit)
    ; BRNE Draw_Bottom_Line ; If X is not 40, loop back and draw the next one

    ; TODO: draw everything once
    ; rcall Draw_BPM
    ; rcall Draw_Sequence
    ; rcall Draw_Octave

    ; -- draw separator line (between sequence and step indicator)
    ldi px_y, 12
    ldi px_state, 1
    ldi px_x, 0
    draw_separator_loop:
    rcall Set_Pixel
    inc px_x
    cpi px_x, 32
    brne draw_separator_loop

    ret

Startup_Display:
    push r17
    lds r17, Current_BPM
    rcall Draw_BPM

    rcall Draw_Sequence
    rcall Draw_Octave

    pop r17
    ret

;---------------------------------------------------------
; ISR: Timer 0 Overflow (Screen Multiplexing)
;---------------------------------------------------------
ISR_Display:
    push temp
    in temp, SREG
    push temp
    push r0
    push r1
    push r17
    push r18
    push r19
    push r23
    push ZL
    push ZH

    lds r19, Active_Row

    LDI r18, 80
    MUL r19, r18
    MOV ZL, r0
    MOV ZH, r1

    CLR r18
    ADD ZL, r18
    ADC ZH, r18

    SUBI ZL, low(-Screen_Buffer)
    SBCI ZH, high(-Screen_Buffer)

    LDI r18, 80
isr_ColLoop:
    LD r1, Z+
    CBI DISPLAY_PORT, DISPLAY_DATA_I
    SBRC r1, 0
    SBI DISPLAY_PORT, DISPLAY_DATA_I
    SBI DISPLAY_PIN, DISPLAY_CLK_I
    SBI DISPLAY_PIN, DISPLAY_CLK_I
    DEC r18
    BRNE isr_ColLoop

    CBI DISPLAY_PORT, DISPLAY_DATA_I
    SBI DISPLAY_PIN, DISPLAY_CLK_I
    SBI DISPLAY_PIN, DISPLAY_CLK_I

    LDI r23, 0b1000000
    MOV temp, r19
    TST temp
    BREQ skip_shift
shift_mask_loop:
    LSR r23
    DEC temp
    BRNE shift_mask_loop
skip_shift:

    shiftBit_macro r23, 6
    shiftBit_macro r23, 5
    shiftBit_macro r23, 4
    shiftBit_macro r23, 3
    shiftBit_macro r23, 2
    shiftBit_macro r23, 1
    shiftBit_macro r23, 0

    SBI DISPLAY_PIN, 4
    CBI DISPLAY_PORT, 4

    INC r19
    CPI r19, 7
    BRNE save_row
    CLR r19
save_row:
    STS Active_Row, r19

    POP ZH
    POP ZL
    POP r23
    POP r19
    POP r18
    pop r17
    POP r1
    POP r0
    POP temp
    OUT SREG, temp
    POP temp
    RETI

;---------------------------------------------------------
; Subroutine: Clear_Screen
; Fills all 560 bytes of the Screen Buffer with 0x00 (Black)
;---------------------------------------------------------
Clear_Screen:
    PUSH ZL
    PUSH ZH
    PUSH XL
    PUSH XH
    PUSH temp

    LDI ZL, low(Screen_Buffer)
    LDI ZH, high(Screen_Buffer)

    LDI XL, low(560)            ; Use X register pair as a 16-bit counter
    LDI XH, high(560)
    CLR temp                    ; Value to write (0 = OFF)

clear_loop:
    ST Z+, temp                 ; Write 0 and increment Z pointer
    SBIW XL, 1                  ; Subtract 1 from the 16-bit counter
    BRNE clear_loop             ; Loop until the counter hits 0

    POP temp
    POP XH
    POP XL
    POP ZH
    POP ZL
    RET

;---------------------------------------------------------
; Subroutine: Set_Pixel
; Input: px_x (r20), px_y (r21), px_state (r22)
;---------------------------------------------------------
Set_Pixel:
    PUSH r19
    PUSH px_x
    PUSH px_y
    PUSH ZL
    PUSH ZH
    PUSH r0
    PUSH r1

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

    POP r1
    POP r0
    POP ZH
    POP ZL
    POP px_y
    POP px_x
    POP r19
    RET

; === drawing current step ===
Draw_Step:
    push temp
    push px_x
    push px_y

    ; -- clear all steps
    ldi temp, 0
    ldi px_y, 13
    ldi px_x, 0
    ldi px_state, 0
clear_steps_loop:
    rcall Set_Pixel
    inc px_x
    cpi px_x, 32
    brne clear_steps_loop

    ; -- draw current step
    lds temp, Step
    ldi px_y, 13
    mov px_x, temp
    ldi px_state, 1
    rcall Set_Pixel

    pop px_y
    pop px_x
    pop temp
    ret
; ===#===

; === drawing the entire sequence ===
Draw_Sequence:
    push temp
    push r17
    push px_x
    push px_y
    push px_state
    push ZL
    push ZH

    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)
    ldi px_x, 0 ; Start at column 0

draw_seq_loop:
    ; 1. Clear the column for this step (Y=0 to 11)
    ldi px_y, 0
    ldi px_state, 0
clear_col_loop:
    rcall Set_Pixel
    inc px_y
    cpi px_y, 12
    brne clear_col_loop

    ; 2. Read the note from the Sequence array
    ld r17, Z+
    cpi r17, 0xFF ; Check if it's a rest/mute
    breq next_step_draw ; skip drawing if muted

    ; 3. Calculate note index Modulo 12 (pitch class)
mod_12_loop:
    cpi r17, 12
    brlo mod_12_done
    subi r17, 12
    rjmp mod_12_loop
mod_12_done:

    ; 4. Map to Y coordinate: 11 - note
    ; This puts C at the bottom (y=11) and B at the top (y=0)
    ldi px_y, 11
    sub px_y, r17

    ; 5. Draw the pixel
    ldi px_state, 1
    rcall Set_Pixel

next_step_draw:
    inc px_x
    cpi px_x, 32
    brne draw_seq_loop ; Loop for all 32 steps

    pop ZH
    pop ZL
    pop px_state
    pop px_y
    pop px_x
    pop r17
    pop temp
    ret
; ===#===

;---------------------------------------------------------
; Subroutine: Draw_Octave
; Prints Current_Octave at x=33, y=5
;---------------------------------------------------------
Draw_Octave:
    push r26
    push px_x
    push px_y

    lds r26, Current_Octave ; Get the current octave (e.g., 0, 1, 2, 3)
    
    ; Current_Octave is 0-indexed, so add 1
    inc r26

    ldi px_x, 33            ; Set X coordinate
    ldi px_y, 5             ; Set Y coordinate
    rcall Draw_Number_3x4   ; Draw the 3x4 digit

    pop px_y
    pop px_x
    pop r26
    ret

;---------------------------------------------------------
; Subroutine: Draw_BPM
; Input: r17 (The current BPM, MIN_BPM=60 to MAX_BPM=200)
;---------------------------------------------------------
Draw_BPM:
    ; -- Protect all registers used in this routine --
    PUSH r18
    PUSH r19
    PUSH r23    ; Hundreds
    PUSH r24    ; Tens
    PUSH r25    ; Units
    PUSH r26    ; Digit to draw
    PUSH px_x
    PUSH px_y
    PUSH ZL
    PUSH ZH

;     ; --- 1. Clear the 3x14 drawing area (avoid ghosting) ---
;     LDI px_x, 37
; clear_box_x:
;     LDI px_y, 0
; clear_box_y:
;     LDI px_state, 0
;     rcall Set_Pixel
;     INC px_y
;     CPI px_y, 14
;     BRNE clear_box_y
;     INC px_x
;     CPI px_x, 40
;     BRNE clear_box_x

    ; --- 1. OPTIMIZED CLEAR (Fix 2) ---
    LDI r18, 7                  ; Loop through the 7 physical hardware rows
    LDI ZL, low(Screen_Buffer)
    LDI ZH, high(Screen_Buffer)
    CLR temp                    ; temp (r16) = 0 (LED OFF)

clear_bpm_area:
    ; Wipe Visual Columns 37, 38, 39 on Bottom Panel (Hardware cols 0, 1, 2)
    std Z+0, temp
    std Z+1, temp
    std Z+2, temp

    ; Wipe Visual Columns 37, 38, 39 on Top Panel (Hardware cols 40, 41, 42)
    std Z+40, temp
    std Z+41, temp
    std Z+42, temp

    ; Move Z to the start of the next 80-byte hardware row
    LDI r19, 80
    ADD ZL, r19
    CLR r19
    ADC ZH, r19
    DEC r18
    BRNE clear_bpm_area

    ; --- 2. BINARY TO BCD (Digit Splitting) ---
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
    ; --- 3. DRAW DIGITS ---
    ; Hundreds Digit (Y = 0)
    TST r23
    BREQ skip_hundreds ; Don't draw leading zero
    MOV r26, r23
    LDI px_x, 37
    LDI px_y, 0
    rcall Draw_Number_3x4
skip_hundreds:

    ; Tens Digit (Y = 5)
    MOV r26, r24
    LDI px_x, 37
    LDI px_y, 5
    rcall Draw_Number_3x4

    ; Units Digit (Y = 10)
    MOV r26, r25
    LDI px_x, 37
    LDI px_y, 10
    rcall Draw_Number_3x4

    ; -- Restore Registers --
    POP ZH
    POP ZL
    POP px_y
    POP px_x
    POP r26
    POP r25
    POP r24
    POP r23
    POP r19
    POP r18
    RET

;---------------------------------------------------------
; Subroutine: Draw_Number_3x4
; Inputs: r26 (Digit 0-9), px_x (r20), px_y (r21)
;---------------------------------------------------------
Draw_Number_3x4:
    PUSH ZL
    PUSH ZH
    PUSH r18
    PUSH r19
    PUSH px_x
    PUSH px_y

    LDI ZL, low(Font3x4 * 2)
    LDI ZH, high(Font3x4 * 2)
    LDI r18, 4
    MUL r26, r18
    ADD ZL, r0
    ADC ZH, r1

    LDI r18, 4
draw_row:
    LPM r19, Z+

    LDI px_state, 0
    SBRC r19, 2
    LDI px_state, 1
    rcall Set_Pixel

    INC px_x
    LDI px_state, 0
    SBRC r19, 1
    LDI px_state, 1
    rcall Set_Pixel

    INC px_x
    LDI px_state, 0
    SBRC r19, 0
    LDI px_state, 1
    rcall Set_Pixel

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
; Font Data
;---------------------------------------------------------
Font3x4:
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
	;.db 0b000, 0b000, 0b000, 0b000  ; blank (for leading zero?)

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