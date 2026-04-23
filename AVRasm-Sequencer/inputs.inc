;
; inputs.inc :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

; === set inputs, init states and ADC configs ===
Inputs_Init:
    ; ---- inputs init ----
    ; ---- ADC (for joystick) ----
    ; -- configure joystick (ADC) input pins
    cbi JS_X_D, JS_X_I ; set joystick x dir pin to input (0)
    cbi JS_Y_D, JS_Y_I ; set joystick y dir pin to input (0)
    ; -- configure ADMUX (multiplexer selection register)
    ; REFS0 = 1 -> AVCC (analog supply current) as voltage reference
    ; ADLAR = 1 -> ADC left adjust the result (only want 8-bit precision so we only read from ADCH)
    ; MUX3:0 = 0000 -> default: ADC0 (PC0 aka x-axis)
    ldi temp, (1<<REFS0) | (1<<ADLAR) ; no bit for mux since 0
    sts ADMUX, temp
    ; -- configure ADCSRA (ADC Control and Status Register A)
    ; ADEN = 1 -> ADC enable
    ; ADPS2:0 = 111 -> prescaler of 128 (16MHz/128=125kHz ADC clock)
    ldi temp, (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)
    sts ADCSRA, temp
    ; --------

    ; -- switch input
    cbi SW_D, SW_I ; dir pin to 0 meaning input
    sbi SW_P, SW_I ; enable pullup for this input pin

    ; -- init JS click input
    cbi JS_BTN_D, JS_BTN_I ; dir pin to 0 meaning input
    sbi JS_BTN_P, JS_BTN_I ; enable pullup for this input pin

    ; -- init JS states
    clr temp ; default joystick state
    sts Prev_JS_Click, temp
    sts Prev_JS_Down, temp
    sts Prev_JS_Up, temp
    sts Prev_JS_Right, temp
    sts Prev_JS_Left, temp

    ; -- init keypad states
    sts Prev_KP_0, temp
    sts Prev_KP_1, temp
    sts Prev_KP_2, temp
    sts Prev_KP_3, temp
    sts Prev_KP_4, temp
    sts Prev_KP_5, temp
    sts Prev_KP_6, temp
    sts Prev_KP_7, temp
    sts Prev_KP_8, temp
    sts Prev_KP_9, temp
    sts Prev_KP_A, temp
    sts Prev_KP_B, temp
    sts Prev_KP_C, temp
    sts Prev_KP_D, temp
    sts Prev_KP_E, temp
    sts Prev_KP_F, temp

    ret
; ===#===

; === handle user inputs (joystick, keypad) ===
User_Inputs:
    rcall Handle_Joystick
    ;rjmp kp_polling_1 ; old name
    rcall Scan_Keypad
    rjmp loop
; ===#===

; === reset all btn states to 0 ===
Reset_Prev_Btn_States:
    rcall Reset_Prev_JS_States
    rcall Reset_Prev_KP_States
    ret

Reset_Prev_JS_States:
    push temp

    clr temp ; aka ldi temp, 0

    sts Prev_JS_Click, temp
    sts Prev_JS_Down, temp
    sts Prev_JS_Up, temp
    sts Prev_JS_Right, temp
    sts Prev_JS_Left, temp

    pop temp
    ret

Reset_Prev_KP_States:
    push temp

    clr temp ; aka ldi temp, 0

    sts Prev_KP_0, temp
    sts Prev_KP_1, temp
    sts Prev_KP_2, temp
    sts Prev_KP_3, temp
    sts Prev_KP_4, temp
    sts Prev_KP_5, temp
    sts Prev_KP_6, temp
    sts Prev_KP_7, temp
    sts Prev_KP_8, temp
    sts Prev_KP_9, temp
    sts Prev_KP_A, temp
    sts Prev_KP_B, temp
    sts Prev_KP_C, temp
    sts Prev_KP_D, temp
    sts Prev_KP_E, temp
    sts Prev_KP_F, temp

    pop temp
    ret
; ===#===

; === handle joystick inputs ===
Handle_Joystick:
    push temp
    push r17
    push r18

    ; -- check joystick click button
    clr temp ; assume button is pressed (0) ; aka ldi temp, 0
    sbic JS_BTN_SENSE, JS_BTN_I ; Skip next instruction if Bit in I/o reg is Cleared (0 aka pressed bc pulled-up)
    ldi temp, 1 ; if pin is HIGH, set temp to 1 (released)
    ; -- edge detection for btn
    lds r17, Prev_JS_Click
    cp temp, r17
    breq Skip_JS_Click_Check ; if state hasn't changed, skip toggle logic
    sts Prev_JS_Click, temp ; state changed, save the new physical state
    cpi temp, 1
    breq Skip_JS_Click_Check ; if changed to 1 (btn released), skip toggle
    ; -- it changed to 0 (aka clicked)
    ; toggle play/pause state
    lds r17, Is_Playing ; load current play state
    ldi r18, 1
    eor r17, r18 ; XOR flips 1 to 0, and 0 to 1, toggles play state
    sts Is_Playing, r17 ; save new play state

    ; -- instantly mute buzzer if just paused
    sbrs r17, 0 ; skip mute if bit 0 is set (playing = 1)
    rcall Mute_Buzzer ; mute if paused (0)

    ; skip rest of joystick handling if just clicked
    rjmp Handle_Joystick_End ; ignore rest of joystick handling if just clicked ?

    Skip_JS_Click_Check:
    ; JS not clicked

    ; -- x-asix
    ldi r18, 0 ; joystick x-axis, CHANNEL 0 of ADC
    rcall Read_ADC ; read ADC value of joystick, store result in r19
    cpi r19, 192 ; compare with high threshold
    brsh joystick_right
    cpi r19, 64 ; compare with low threshold
    brlo joystick_left
    ; -- y-axis
    ldi r18, 1 ; joystick y-axis, CHANNEL 1 of ADC
    rcall Read_ADC ; read ADC value of joystick, store result in r19
    cpi r19, 192 ; compare with high threshold
    brsh joystick_down
    cpi r19, 64 ; compare with low threshold
    brlo joystick_up

    ; -- joystick in center (or in deadzone)
    rjmp joystick_center

    Handle_Joystick_End: ; don't forget to restore and ret

    ; -- restore
    pop r18
    pop r17
    pop temp
    ret

joystick_left:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    ; -- move to previous step
    rcall Prev_Step_btn
    rjmp Handle_Joystick_End
joystick_right:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- move to next step
    rcall Next_Step_btn
    rjmp Handle_Joystick_End
joystick_down:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- decrease BPM
    rcall Decr_BPM_btn
    rjmp Handle_Joystick_End
joystick_up:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- increase BPM
    rcall Incr_BPM_btn
    rjmp Handle_Joystick_End
joystick_center:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- turn off debug LEDs
    rcall LED2_OFF
    rcall LED3_OFF
    rjmp Handle_Joystick_End

; --- ADC reading for joystick ---
; input r18 = ADC channel to read (0-7)
; output r19 = ADC value (0-255)
Read_ADC:
    push temp

    ; -- set channel
    andi r18, 0b00001111 ; channel must be 0-15 because MUX3:0 are only 4 bits
    ori r18, (1<<REFS0) | (1<<ADLAR) ; apply reference and left-adjust bits again (see setup)
    sts ADMUX, r18 ; write to ADMUX to set channel (and reference/adjust bits again like in setup)

    ; -- start conversion
    lds temp, ADCSRA ; read current value of ADC Control and Status Register A
    ori temp, (1<<ADSC) ; set the ADC Start Conversion bit
    sts ADCSRA, temp ; write back to ADCSRA to start conversion

    Wait_For_ADC:
    ; -- wait for the conversion end
    ; QDC hardware will automatically clear the ADSC bit when done
    lds temp, ADCSRA ; read ADCSRA to check ADSC bit
    sbrc temp, ADSC ; skip next if ADSC is 0
    rjmp Wait_For_ADC ; loop back up, keep waiting
    
    ; conversion done

    ; -- get result value
    lds r19, ADCH ; output (read only the high byte for 8-bit resolution!)

    ; -- restore
    pop temp
    ret
; ---#---
; ===#===

; === Keypad scanning/polling routine step 2 ===
; making this a macro can make it more elegant
;KP_POLLING_2:
.macro KP_POLLING_2
    ; CAREFUL: need to first modify PORT reg before modifying DDR reg.
    ; -- rows as inputs:
    ldi temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
    out KP_PORT,temp ; bitmask to keypad port for rows
    ; -- cols as outputs:
    ldi temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
    out KP_DDR,temp ; bitmask to keypad port dir for cols

    nop ; no operation because "Add NOP when changing output connected to an input" slide 8 ("Bits in PINx register are always one cycle behind", synchronizer: PIN reg 1 clk-cycle late)
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
    ;ret ; i guess shoudln't happen
.endmacro
; ===#===

; === Keypad scanning/polling routine ===
; this does the "2-step method" switching for the keypad
; - config all rows output, set them LOW
; - config all cols input, check which low
;    - the col y that is low has a btn pressed => col num Y
;    - config all rows input, all cols output
;    - => careful transition, intermediate pin states ! context switching
;    - set all cols to LOW, check row pins
;        - if all rows HIGH => btn release, exit
;        - if row x is LOW => btn pressed in Y col => row num X
;        - => btn pressed is row-X and col-Y
; - if no col is low (=all high) no btn is pressed, exit
Scan_Keypad:
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
    ;ret ; i guess shoudln't happen

no_kp_pressed:
    ; -- reset keypad states (for edge detection/software debouncing)
    rcall Reset_Prev_KP_States ; reset all btn states to 0 (no btn pressed)
    ret ; dont forget ret here!

col1pressed:
    ; col Y=1
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col1row1,col1row2,col1row3,col1row4 ; macro with args to rjmp to corresponding label
col2pressed:
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col2row1,col2row2,col2row3,col2row4 ; macro with args to rjmp to corresponding label
    ;ret ; i guess don't happen
col3pressed:
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col3row1,col3row2,col3row3,col3row4 ; macro with args to rjmp to corresponding label
    ;ret ; i guess don't happen
col4pressed:
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col4row1,col4row2,col4row3,col4row4 ; macro with args to rjmp to corresponding label
    ;ret ; i guess don't happen

; --- COL 1 ---
col1row1: ; "7" => G#
    push temp
    push r18

    ; -- edge detection, check KP_7 state
    lds temp, Prev_KP_7
    tst temp ; test for 0
    brne Skip_KP_7 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_7, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 8 ; NOTE_G#* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_7:
    pop r18
    pop temp
    ret
col1row2: ; "4" => E
    push temp
    push r18

    ; -- edge detection, check KP_4 state
    lds temp, Prev_KP_4
    tst temp ; test for 0
    brne Skip_KP_4 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_4, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 4 ; NOTE_E* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_4:
    pop r18
    pop temp
    ret
col1row3: ; "1" => C
    push temp
    push r18

    ; -- edge detection, check KP_1 state
    lds temp, Prev_KP_1
    tst temp ; test for 0
    brne Skip_KP_1 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_1, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 0  ; NOTE_C* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_1:
    pop r18
    pop temp
    ret
col1row4: ; "A"
    ; decrease octave
    push r18

    ; -- edge detection, check KP_A state
    lds temp, Prev_KP_A
    tst temp ; test for 0
    brne Skip_Decr_Octave ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_A, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    rcall LED3_ON ; FIXME: DEBUG

    lds r18, Current_Octave ; get current octave
    cpi r18, 1 ; compare with min octave (1)
    brlo Skip_Decr_Octave ; if octave < 1, skip decrease

    dec r18 ; decrease octave
    sts Current_Octave, r18 ; save new octave
    rcall Draw_Octave ; update octave on screen

    Skip_Decr_Octave:
    pop r18
    ret

; --- COL 2 ---
col2row1: ; "8" => A
    push temp
    push r18

    ; -- edge detection, check KP_8 state
    lds temp, Prev_KP_8
    tst temp ; test for 0
    brne Skip_KP_8 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_8, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 9 ; NOTE_A* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_8:
    pop r18
    pop temp
    ret
col2row2: ; "5" => F
    push temp
    push r18

    ; -- edge detection, check KP_5 state
    lds temp, Prev_KP_5
    tst temp ; test for 0
    brne Skip_KP_5 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_5, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 5  ; NOTE_F* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_5:
    pop r18
    pop temp
    ret
col2row3: ; "2" => C#
    push temp
    push r18

    ; -- edge detection, check KP_2 state
    lds temp, Prev_KP_2
    tst temp ; test for 0
    brne Skip_KP_2 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_2, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 1  ; NOTE_C#* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_2:
    pop r18
    pop temp
    ret
col2row4: ; "0"
    ; increase octave
    push r18

    ; -- edge detection, check KP_0 state
    lds temp, Prev_KP_0
    tst temp ; test for 0
    brne Skip_Incr_Octave ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_0, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    rcall LED2_ON ; FIXME: DEBUG

    lds r18, Current_Octave ; get current octave
    cpi r18, 3 ; compare with max octave (4 but 0-indexed)
    brsh Skip_Incr_Octave ; if octave > 3, skip increase

    inc r18 ; increase octave
    sts Current_Octave, r18 ; save new octave
    rcall Draw_Octave ; update octave on screen

    Skip_Incr_Octave:
    pop r18
    ret

; --- COL 3 ---
col3row1: ; "9" => A#
    push temp
    push r18

    ; -- edge detection, check KP_9 state
    lds temp, Prev_KP_9
    tst temp ; test for 0
    brne Skip_KP_9 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_9, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 10 ; NOTE_A#* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_9:
    pop r18
    pop temp
    ret
col3row2: ; "6" => F#
    push temp
    push r18

    ; -- edge detection, check KP_6 state
    lds temp, Prev_KP_6
    tst temp ; test for 0
    brne Skip_KP_6 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_6, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 6 ; NOTE_F#* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_6:
    pop r18
    pop temp
    ret
col3row3: ; "3" => D
    push temp
    push r18

    ; -- edge detection, check KP_3 state
    lds temp, Prev_KP_3
    tst temp ; test for 0
    brne Skip_KP_3 ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_3, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 2  ; NOTE_D* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_3:
    pop r18
    pop temp
    ret
col3row4: ; "B"
    ; TODO: do something ?
    push temp

    ; -- edge detection, check KP_B state
    lds temp, Prev_KP_B
    tst temp ; test for 0
    brne Skip_KP_B ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_B, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ; ...
    ; ...
    ; ...

    Skip_KP_B:
    pop temp
    ret

; --- COL 4 ---
col4row1: ; "F" => B
    push temp
    push r18

    ; -- edge detection, check KP_F state
    lds temp, Prev_KP_F
    tst temp ; test for 0
    brne Skip_KP_F ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_F, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 11 ; NOTE_B* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_F:
    pop r18
    pop temp
    ret
col4row2: ; "E" => G
    push temp
    push r18

    ; -- edge detection, check KP_E state
    lds temp, Prev_KP_E
    tst temp ; test for 0
    brne Skip_KP_E ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_E, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 7 ; NOTE_G* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_E:
    pop r18
    pop temp
    ret
col4row3: ; "D" => D#
    push temp
    push r18

    ; -- edge detection, check KP_D state
    lds temp, Prev_KP_D
    tst temp ; test for 0
    brne Skip_KP_D ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_D, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 3  ; NOTE_D#* idx

    ; add octave offset to note idx (12 notes per octave)
    lds r18, Current_Octave ; get current octave
    ldi temp, 12
    mul r18, temp ; octave num * 12 ; RESULT IS IN r1(high-byte):r0(low-byte)
    add r17, r0 ; add octave offset to note idx (only low-byte of mult result)

    rcall Set_Current_Sequence_Note

    Skip_KP_D:
    pop r18
    pop temp
    ret
col4row4: ; "C" => mute(no note/blank) current step
    ; clear/mute current step note
    push temp

    ; -- edge detection, check KP_C state
    lds temp, Prev_KP_C
    tst temp ; test for 0
    brne Skip_KP_C ; state didn't change, skip

    ldi temp, 1
    sts Prev_KP_C, temp ; store new state (1)
    ; DON'T FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)
    ; or reset state when no_kp_pressed

    ; -- it changed to pressed

    ldi r17, 0xFF ; special idx meaning "no note" or "mute"
    rcall Set_Current_Sequence_Note ; input is r17 = note idx

    Skip_KP_C:
    pop temp
    ret
; ===#===

; === handle manual sequencer steps ===
Next_Step_btn:
    push temp
    push r22
    ; advance to next step in sequence
    ; -- edge detection
    lds r22, Prev_JS_Right
    cpi r22, 1 ; was prev state right 1 ?
    breq Skip_Right_Check ; if state hasn't changed (still right), do nothing
    ldi r22, 1 ; new state is right 1
    sts Prev_JS_Right, r22 ; save new state
    ; DON'T FORGET TO SET BACK TO 0 AFTER RELEASED

    rcall Next_Step
    rcall Draw_Step
    rcall LED2_ON ; FIXME: DEBUG

    ; if paused, play the note at the new step
    lds temp, Is_Playing
    sbrs temp, 0 ; Skip if bit 0 is set (playing)
    rcall play_new_step_note_manual ; If paused, play the note

    Skip_Right_Check:
    pop r22
    pop temp
    ret

Prev_Step_Btn:
    push temp
    push r22
    ; move back to previous step in sequence
    ; -- edge detection
    lds r22, Prev_JS_Left
    cpi r22, 1 ; was prev state left 1 ?
    breq Skip_Left_Check ; if state hasn't changed (still left), do nothing
    ldi r22, 1 ; new state is left 1
    sts Prev_JS_Left, r22 ; save new state
    ; DON'T FORGET TO SET BACK TO 0 AFTER RELEASED

    rcall Prev_Step
    rcall Draw_Step
    rcall LED3_ON ; FIXME: DEBUG

    ; if paused, play the note at the new step
    lds temp, Is_Playing
    sbrs temp, 0 ; Skip if bit 0 is set (playing)
    rcall play_new_step_note_manual ; If paused, play the note

    Skip_Left_Check:
    pop r22
    pop temp
    ret

play_new_step_note_manual:
    push ZL
    push ZH
    push r17
    push temp

    ; -- play note for current step
    lds r17, Step ; get current step index
    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)
    clr temp ; clear temp for high byte addition
    add ZL, r17 ; add step index to z pointer to point to current step's note in sequence
    adc ZH, temp ; add carry to high byte (ZH) from low byte addition
    ld r17, Z ; load current step's note index into r17
    rcall Play_Note ; play the note for the current step (r17 is input idx)

    pop temp
    pop r17
    pop ZH
    pop ZL
    ret
; ===#===

; === handle BPM changes from joystick ===
Incr_BPM_btn:
    push temp
    push r17

    ; -- edge detection
    lds temp, Prev_JS_Up
    tst temp ; test for 0
    brne Skip_Incr_BPM_btn ; state didn't change, skip

    ldi temp, 1
    sts Prev_JS_Up, temp ; store new state (1)
    ; DO NOT FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)

    ; -- increase bpm
    lds r17, Current_BPM
    cpi r17, MAX_BPM
    brsh Incr_BPM_btn_end ; BPM already at max value
    inc r17
    rcall Update_BPM ; will also save to SRAM
    rcall LED2_ON ; FIXME: DEBUG

    Incr_BPM_btn_end:
    Skip_Incr_BPM_btn:
    pop r17
    pop temp
    ret

Decr_BPM_btn:
    push temp
    push r17

    ; -- edge detection
    lds temp, Prev_JS_Down
    tst temp ; test for 0
    brne Skip_Decr_BPM_btn ; state didn't change, skip

    ldi temp, 1
    sts Prev_JS_Down, temp ; store new state (1)
    ; DO NOT FORGET TO RESTORE TO 0 LATER (like at Metronome ISR?)

    ; -- decrease bpm
    lds r17, Current_BPM
    cpi r17, MIN_BPM+1
    brlo Decr_BPM_btn_end ; BPM already at min value
    dec r17
    rcall Update_BPM ; will also save to SRAM
    rcall LED3_ON ; FIXME: DEBUG

    Decr_BPM_btn_end:
    Skip_Decr_BPM_btn:
    pop r17
    pop temp
    ret
; ===#===

; === set current sequence note ===
; input r17 is note idx to put at the current step
Set_Current_Sequence_Note:
    push ZL
    push ZH
    push r18
    push temp

    ; -- get the current step, 0-31
    lds r18, Step

    ; -- set z pointer to start of Sequence
    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)

    ; -- add Step offset to z pointer (Sequence + Step)
    clr temp
    add ZL, r18
    adc ZH, temp

    ; -- store the newest note into SRAM
    st Z, r17

    ; -- update the screen
    rcall Draw_Sequence

    ; -- play note instantly to hear it (especially useful when paused)
    rcall Play_Note

    ; -- restore
    pop temp
    pop r18
    pop ZH
    pop ZL
    ret
; ===#===
