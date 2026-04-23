;
; display.inc :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;


; === init of the screen ===
Init_Display:
    ; init Active_Row to 0
    clr temp
    sts Active_Row, temp

    ; clear the displya buffer to black (0)
    rcall Clear_Screen

    ; ; DEBUG: test
    ; ldi px_x, 5
    ; ldi px_y, 8
    ; ldi px_state, 1 ; state = ON
    ; rcall Set_Pixel

    ; ; DEBUG: test
    ; ldi px_y, 13 ; y coord
    ; ldi px_state, 1 ; state = ON
    ; ldi px_x, 0 ; start x coord at 0
    ; Draw_Bottom_Line:
    ; rcall Set_Pixel ; draw this pixel
    ; inc px_x ; move right 1 pixel 
    ; cpi px_x, 32 ; compare x with max
    ; brne Draw_Bottom_Line ; if x is not 32, loop back and draw next pixel

    ; ; DEBUG: draw everything once
    ; rcall Draw_BPM
    ; rcall Draw_Sequence
    ; rcall Draw_Octave

    ; -- draw separator line (between sequence and step indicator)
    ldi px_y, 12
    ldi px_state, 1
    ldi px_x, 0
    Draw_Separator_Loop:
    rcall Set_Pixel
    inc px_x
    cpi px_x, 32
    brne Draw_Separator_Loop

    ret
; ===#===

; === apply correct info to screen at statup ===
Startup_Display:
    push r17
    lds r17, Current_BPM ; get current BPM from SRAM
    rcall Draw_BPM

    rcall Draw_Sequence
    rcall Draw_Octave
    rcall Draw_Step

    pop r17
    ret
; ===#===

; === macro for shifting a bit of the row mask into the data line (in ISR below) ===
.macro Shift_Bit_macro
    sbi DISPLAY_PORT, DISPLAY_DATA_I ; set data line to 1
    sbrs @0, @1 ; skip if bit @1 of reg@0 is set (if the bit of the mask for this row is 1, we want to set the data line to 1, otherwise we want to leave it at 0)
    cbi DISPLAY_PORT, DISPLAY_DATA_I ; set data line to 0 if bit @1 of reg@0 is clear
    sbi DISPLAY_PIN, DISPLAY_CLK_I ; clock the data line to shift it into the shift register
    sbi DISPLAY_PIN, DISPLAY_CLK_I ; toggles back the clock line
.endmacro
; ===#===

; === ISR for timer0 overflow (screen multiplexing) ===
; called every Xms/us (see timer0 settings) to udpate the display for the next active row
; it works by, each time it's called, updating the shift registesr to output the correct pixels for that row
ISR_Display:
    push r0
    push r1
    push temp
    in temp, SREG ; let's push SREG in case we mess with branching and stuff in this ISR
    push temp
    push r17
    push r18
    push r19
    push r23
    push ZL
    push ZH

    lds r19, Active_Row ; get active row (0-6)

    ldi r18, 80 ; num pixels per row (physical row not logical drawing row)
    mul r19, r18 ; row num * 80 (num pixels per row) to get start address of this row in screen buffer
    mov ZL, r0 ; low byte of mult result is in r0
    mov ZH, r1 ; high byte of mult result is in r1

    clr r18 ; aka ldi r18, 0
    add ZL, r18 ; add x offset (0 for now since we're diong full rows)
    adc ZH, r18 ; add carry to high byte

    subi ZL, low(-Screen_Buffer) ; convert to address in flash mem
    sbci ZH, high(-Screen_Buffer) ; same with carry

    ldi r18, 80 ; num pixels per row (physical row not logical drawing row)
    isr_Col_Loop:
    ld r1, Z+ ; load this pixel value (0 or 1) from screen buffer and post-increment Z pointer
    cbi DISPLAY_PORT, DISPLAY_DATA_I ; default to 0 (off)
    sbrc r1, 0 ; skip if bit 0 of r1 is clear (pixel value is 0, keep it off)
    sbi DISPLAY_PORT, DISPLAY_DATA_I ; set to 1 (on) if bit 0 of r1 is set (pixel value is 1)
    sbi DISPLAY_PIN, DISPLAY_CLK_I ; clock the data line to shift it into the shift register
    sbi DISPLAY_PIN, DISPLAY_CLK_I ; toggles back the clock line
    dec r18 ; decrement pixel counter
    brne isr_Col_Loop ; loop until we've done all 80 pixels in this row

    cbi DISPLAY_PORT, DISPLAY_DATA_I ; reset data line to 0 after the row is done
    sbi DISPLAY_PIN, DISPLAY_CLK_I ; clock the data line to shift it into the shift register (to make sure the last pixel is registered)
    sbi DISPLAY_PIN, DISPLAY_CLK_I ; toggles back the clock line

    ldi r23, 0b1000000 ; bit mask to get the correct bit from r19 (active row num) for the shift register
    mov temp, r19 
    tst temp ; if active row is 0, we don't need to shift the mask, otherwise we do (shift left by active row num)
    breq Skip_Shift ; if active row is 0, skip the shifting
    Shift_Mask_Loop:
    lsr r23 ; shift the mask right by 1 (equivalent to shifting left by 1 on the next iteration)
    dec temp ; decrement the temp counter (which started as active row num)
    brne Shift_Mask_Loop ; loop until we've shifted the mask the correct number of times
    Skip_Shift:

    ; muhc more elegant using a macro
    ; operands of macro: @0 is reg, @1 is bit num
    Shift_Bit_macro r23, 6 ; shift the correct bit of the mask into the data line to select the correct row on the display
    Shift_Bit_macro r23, 5
    Shift_Bit_macro r23, 4
    Shift_Bit_macro r23, 3
    Shift_Bit_macro r23, 2
    Shift_Bit_macro r23, 1
    Shift_Bit_macro r23, 0

    sbi DISPLAY_PIN, 4 ; set latch pin high to output the row data to the display
    cbi DISPLAY_PORT, 4 ; set latch pin low again to prepare for the next row (latch on falling edge)

    inc r19 ; increment active row
    cpi r19, 7 ; if active row is 7 (beyond last row), reset to 0
    brne Save_Row ; if active row is not 7, save it and exit
    clr r19 ; reset to 0
    Save_Row:
    sts Active_Row, r19 ; save new active row num to SRAM

    ; restore
    pop ZH
    pop ZL
    pop r23
    pop r19
    pop r18
    pop r17
    pop temp
    out SREG, temp
    pop temp
    pop r1
    pop r0
    reti ; don't forget the i because ISR, bruh
; ===#=== 

; === clear screen ===
; fills all 560 bytes of the Screen_Buffer with 0x00 (off)
Clear_Screen:
    push ZL
    push ZH
    push XL ; let's use the x registers to use the sbiw intruction for the counter
    push XH
    push temp

    ; -- load address of Screen_Buffer in flash mem into é register pair
    ldi ZL, low(Screen_Buffer)
    ldi ZH, high(Screen_Buffer)

    ; -- load 560 (num bytes in screen buffer) into x register pair as a counter
    ldi XL, low(560) ; use x registers for 16-bit counter
    ldi XH, high(560) ; allows to use the sbiw instruction do decr 16-bit number
    clr temp ; value to write to buffer (0=off) ; aka ldi temp, 0

    Clear_Screen_Loop:
    st Z+, temp ; write 0 to a byte in Screen_Buffer and increment Z pointer
    sbiw XL, 1 ; sub immidiate from word (aka 16-bit), meaning decr counter
    brne Clear_Screen_Loop ; loop until the counter hits 0

    POP temp
    POP XH
    POP XL
    POP ZH
    POP ZL
    RET
; ===#===

; === set pixel at x and y coordinates to on or off ===
; input  px_x (r20), px_y (r21), px_state (r22)
; the x and y coords are logical positions of the pixels (easier for me)
Set_Pixel:
    push r19
    push px_x
    push px_y
    push ZL
    push ZH
    push r0
    push r1

    ; -- if y < 7, top half of display, otherwise bottom half (electrically only one 7x40)
    cpi px_y, 7
    brsh Bottom_Half_Display

    Top_Half_Display:
    ldi r19, 79 ; max x coord for top half (40-79)
    sub r19, px_x ; invert x coord for top half because of how the display is placed (physically mirrored horizontally)
    mov px_x, r19 ; update x coord with the inverted value for the top half
    ldi r19, 6 ; max y coord for top half is 6 (0-6)
    sub r19, px_y ; invert y coord for top half because of how the display is placed (physically mirrored vertically also)
    mov px_y, r19 ; update y coord with the inverted value for the top half
    rjmp Compute_Pixel_Address

    Bottom_Half_Display:
    ldi r19, 39 ; max x coord for bottom half (0-39)
    sub r19, px_x ; invert x coord for bottom half because of how the display is placed (physically mirrored horizontally)
    mov px_x, r19 ; update x coord with the inverted value for the bottom half
    ldi r19, 13 ; max y coord for bottom half is 13 (7-13)
    sub r19, px_y ; invert y coord for bottom half because of how the display is placed (physically mirrored vertically also)
    mov px_y, r19 ; update y coord with the inverted value for the bottom half
    ;rjmp Compute_Pixel_Address

    Compute_Pixel_Address:
    ldi r19, 80 ; num pixels per row (physical row not logical drawing row)
    mul px_y, r19 ; y coord * num pixels per row to get start address of this row in Screen_Buffer
    mov ZL, r0 ; low byte of mult result is in r0
    mov ZH, r1 ; high byte of mult result is in r1
    clr r19 ; aka ldi r19, 0
    add ZL, px_x ; add x coord to get address of this pixel in Screen_Buffer
    adc ZH, r19 ; add carry to high byte
    subi ZL, low(-Screen_Buffer) ; convert to address in flash mem
    sbci ZH, high(-Screen_Buffer) ; same with carry
    st Z, px_state ; store the pixel state (0 or 1) in the correct pixel address in Screen_Buffer

    pop r1
    pop r0
    pop ZH
    pop ZL
    pop px_y
    pop px_x
    pop r19
    ret
; ===#===

; === drawing current step ===
Draw_Step:
    push temp
    push px_x
    push px_y

    ; -- clear all steps on screen first
    ldi temp, 0
    ldi px_y, 13
    ldi px_x, 0
    ldi px_state, 0
    Clear_All_Steps_Loop:
    rcall Set_Pixel
    inc px_x
    cpi px_x, 32
    brne Clear_All_Steps_Loop

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

    ; -- load address of Sequence in flash mem
    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)
    
    ldi px_x, 0 ; Start at column 0

    Draw_Sequence_Loop:
    ; -- clear the column for this step (y=0 to 11)
    ldi px_y, 0
    ldi px_state, 0
    Clear_Seq_Col_Loop:
    rcall Set_Pixel
    inc px_y ; move down 1 pixel
    cpi px_y, 12 ; if y < 12, loop and clear next
    brne Clear_Seq_Col_Loop

    ; -- read note from Sequence
    ld r17, Z+ ; load note index for this step and post-increment Z pointer

     ; -- if it's a rest/mute (0xFF), skip drawing the note
    cpi r17, 0xFF ; 0xFF = mute/rest/blank note
    breq Skip_Drawing_Muted_Note

    ; -- calculate note index modulo 12 (whichever octave, still draw the correct ntoe)
    Modulo_12_Loop:
    cpi r17, 12 ; if note idx < 12, we're done
    brlo Modulo_12_Done
    subi r17, 12 ; sub 12 to get lower octave's note idx
    rjmp Modulo_12_Loop
    Modulo_12_Done:

    ; -- map Y coord: 11 - note
    ; C at the bottom (y=11) and B at the top (y=0)
    ldi px_y, 11
    sub px_y, r17 ; subtract note idx from 11 to get y coord (C=0 -> 11, etc, B=11 -> 0)

    ; -- draw pixel for note
    ldi px_state, 1
    rcall Set_Pixel

    Skip_Drawing_Muted_Note:
    inc px_x ; move to next column for next step
    cpi px_x, 32 ; if x < 32, loop and draw next step
    brne Draw_Sequence_Loop

    pop ZH
    pop ZL
    pop px_state
    pop px_y
    pop px_x
    pop r17
    pop temp
    ret
; ===#===

; === draw Current_Octave number ===
Draw_Octave:
    push r26
    push px_x
    push px_y

    ; -- get the current octave
    lds r26, Current_Octave
    inc r26 ; 0-indexed, so add 1 to for displaying

    ldi px_x, 33 ; x coord for octave display
    ldi px_y, 5 ; y coord for octave display
    rcall Draw_Number_3x4 ; draw number using 3x4 font

    pop px_y
    pop px_x
    pop r26
    ret
; ===#===

; === Draw_BPM ===
; input r17 (current BPM, MIN_BPM=60 to MAX_BPM=200)
Draw_BPM:
    push r18
    push r19
    push r23 ; hundreds
    push r24 ; tens
    push r25 ; units
    push r26 ; digit to draw
    push px_x
    push px_y
    push ZL
    push ZH

;     ; -- clear the 3x14 BPM drawing area
;     ldi px_x, 37
;     Clear_BPM_Box_X:
;         ldi px_y, 0
;         Clear_BPM_Box_Y:
;             ldi px_state, 0
;             rcall Set_Pixel
;             inc px_y
;             cpi px_y, 14
;         brne Clear_BPM_Box_Y
;         inc px_x
;         cpi px_x, 40
;     brne Clear_BPM_Box_X

    ; -- OPTIMIZED CLEAR
    ; instead of 42 iterations (3 cols x 14 rows), do 7 iterations (1 for each hardware row), and in each iteration clear the 3 pixels of the BPM area that are on that hardware row (since the BPM area is only 3 pixels wide, we can clear all 3 with just 3 instructions, no need for a loop)
    ldi r18, 7 ; loop through the 7 physical hardware rows
    ldi ZL, low(Screen_Buffer)
    ldi ZH, high(Screen_Buffer)
    clr temp ; temp = 0 (LED off) ; aka ldi temp, 0

    Clear_BPM_Area_Loop:
    ; -- clear visual cols 37, 38, 39 on bottom half (electrical cols 0, 1, 2)
    std Z+0, temp
    std Z+1, temp
    std Z+2, temp

    ; -- clear visual cols 37, 38, 39 on top panel (electrical cols 40, 41, 42)
    std Z+40, temp
    std Z+41, temp
    std Z+42, temp

    ; -- move Z to the start of the next 80-byte hardware row
    ldi r19, 80 ; num pixels per row (physical row not logical drawing row)
    add ZL, r19 ; move z pointer down to next hardware row
    clr r19 ; aka ldi r19, 0
    adc ZH, r19 ; add carry to high byte
    dec r18 ; decrement row counter
    brne Clear_BPM_Area_Loop ; loop until we've cleared all 7 hardware rows that contain the BPM digits

    ; -- split digits of BPM (max 3 digits bc BPM_MAX=200)
    clr r23 ; hundreds digit ; aka ldi r23, 0
    clr r24 ; tens digit ; aka ldi r24, 0
    mov r25, r17 ; units digit starts as the full BPM value, we'll sub 10 or 100 from it to get the tens and hundreds digits

    count_100:
    cpi r25, 100 ; if BPM < 100, we're done with the hundreds digit
    brlo count_10
    subi r25, 100 ; sub 100 from units to get the tens digit
    inc r23 ; increment hundreds digit
    rjmp count_100 ; max twice since BPM_MAX=200

    count_10:
    cpi r25, 10 ; if BPM < 10, we're done with the tens digit
    brlo Draw_BPM_Digits
    subi r25, 10 ; sub 10 from units to get the units digit
    inc r24 ; increment tens digit
    rjmp count_10 ; loop until subbed all 10s from the units digit to get the correct tens digit

    ; now r25 only has the units digit, r24 has the tens digit and r23 has the hundreds digit

    ; -- draw digits
    Draw_BPM_Digits:
    ; -- hundreds digit (top)
    tst r23 ; dont draw leading zero (will be blank)
    breq Skip_Hundreds
    mov r26, r23 ; move hundreds digit to r26 for drawing
    ldi px_x, 37 ; x coord for BPM digits
    ldi px_y, 0 ; y coord for hundreds digit
    rcall Draw_Number_3x4

    Skip_Hundreds:

    ; -- tens digit (middle)
    mov r26, r24 ; move tens digit to r26 for drawing
    ldi px_x, 37 ; x coord for BPM digits
    ldi px_y, 5 ; y coord for tens digit
    rcall Draw_Number_3x4

    ; -- units digit (bottom)
    mov r26, r25 ; move units digit to r26 for drawing
    ldi px_x, 37 ; x coord for BPM digits
    ldi px_y, 10 ; y coord for units digit
    rcall Draw_Number_3x4

    ; -- restore
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

; === draw a number using the 3x4 font ===
; inputs r26 (digit 0-9), px_x (r20), px_y (r21)
Draw_Number_3x4:
    push ZL
    push ZH
    push r18
    push r19
    push px_x
    push px_y

    ; -- calculate address of this digit in font data
    ldi ZL, low(Font_3x4 * 2) ; each digit is 4 bytes, so multiply by 2 to get the correct address for the digit (0-9)
    ldi ZH, high(Font_3x4 * 2) ; same for high byte
    ldi r18, 4 ; num bytes per digit
    mul r26, r18 ; digit index * num bytes per digit to get start address of this digit in font data
    add ZL, r0 ; add result of mult (in r0) = start address of this digit to low byte of font address
    adc ZH, r1 ; add carry to high byte

    ldi r18, 4 ; num rows in font (4)
    Draw_Row_Number_3x4_Loop:
    lpm r19, Z+ ; load this row of the font for this digit and post-increment z pointer

    ldi px_state, 0 ; default to off
    sbrc r19, 2 ; skip if bit 2 of this font row is clear (if the bit for this pixel is 0, keep it off)
    ldi px_state, 1 ; set to 1 (on) if pixel should be on
    rcall Set_Pixel

    inc px_x ; move right 1 pixel
    ldi px_state, 0 ; default to off
    sbrc r19, 1 ; skip if bit 1 of this font row is clear (if the bit for this pixel is 0, keep it off)
    ldi px_state, 1 ; set to 1 (on) if pixel should be on
    rcall Set_Pixel

    inc px_x ; move right 1 pixel
    ldi px_state, 0 ; default to off
    sbrc r19, 0 ; skip if bit 0 of this font row is clear (if the bit for this pixel is 0, keep it off)
    ldi px_state, 1 ; set to 1 (on) if pixel should be on
    rcall Set_Pixel

    ; -- move to the next row (down 1 pixel and back to the first column of the digit)
    dec px_x
    dec px_x
    inc px_y
    dec r18 ; decrement row counter (starts at 4)
    brne Draw_Row_Number_3x4_Loop ; loop until we've drawn all 4 rows of the digit

    ; -- restore
    pop px_y
    pop px_x
    pop r19
    pop r18
    pop ZH
    pop ZL
    ret
; ===#===

; === 3x4 pixel font data ===
Font_3x4:
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
    ;.db 0b000, 0b000, 0b000, 0b000  ; blank (for leading zero?) ; not used, just clear area

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

; ===#===
