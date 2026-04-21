;
; inputs.asm :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

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
	; TODO: fill
	sts Prev_KP_9, temp
	sts Prev_KP_A, temp
	; TODO: fill
	sts Prev_KP_E, temp
	sts Prev_KP_F, temp

	; ----#----
	ret

; === handle user inputs (joystick, keypad) ===
User_Inputs:
    rcall Handle_Joystick
    ;rjmp kp_polling_1 ; ? rjmp or rcall ?
    rcall Scan_Keypad ; ? rjmp or rcall ?
    rjmp loop
; ===#===

; === handle joystick inputs ===
Handle_Joystick:
    push temp
    push r17
    push r18

    ; FIXME:
    ; ; -- check JS click button
    ; sbis JS_BTN_SENSE, JS_BTN_I ; Skip if Bit in I/o reg is Set (skip if click not pressed), bc btn pulled up
    ; rcall Play_Pause_btn ; if click pressed, toggle play/pause

    ; -- check joystick click button
    clr temp ; assume button is pressed (0)
    sbic JS_BTN_SENSE, JS_BTN_I ; Skip next instruction if Bit in I/o reg is Cleared (0 aka pressed bc pulled-up)
    ldi temp, 1 ; If pin is HIGH, set temp to 1 (released)
    ; -- edge detection for btn
    lds r17, Prev_JS_Click
    cp temp, r17
    breq Skip_Click_Check ; if state hasn't changed, skip toggle logic
    sts Prev_JS_Click, temp ; state changed, save the new physical state
    cpi temp, 1
    breq Skip_Click_Check ; if changed to 1 (btn released), skip toggle
    ; -- it changed to 0 (aka clicked)
    ; toggle play/pause state
    lds r17, Is_Playing
    ldi r18, 1
    eor r17, r18 ; XOR flips 1 to 0, and 0 to 1
    sts Is_Playing, r17

    ; TODO: ??
    ; instantly mute buzzer if just paused
    sbrc r17, 0 ; skip mute if bit 0 is set (playing = 1)
    rcall Mute_Buzzer ; mute if paused (0) ; TODO: something else

    ; TODO: ?
    rjmp Handle_Joystick_End ; ignore rest of joystick handling if just clicked ?

    Skip_Click_Check:

    ; -- x-asix
    ldi r18, 0 ; joystick x-axis
    rcall Read_ADC ; read ADC value of joystick, store result in r19
    cpi r19, 192 ; compare with high threshold
    brsh joystick_right
    cpi r19, 64 ; compare with low threshold
    brlo joystick_left
    ; -- y-axis
    ldi r18, 1 ; joystick y-axis
    rcall Read_ADC ; read ADC value of joystick, store result in r19
    cpi r19, 192 ; compare with high threshold
    brsh joystick_down
    cpi r19, 64 ; compare with low threshold
    brlo joystick_up

    ; -- joystick in center (or in deadzone)
    rcall joystick_center

    Handle_Joystick_End:

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
    ret
joystick_right:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- move to next step
    rcall Next_Step_btn
    ret
joystick_down:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- decrease BPM
    rcall Decr_BPM_btn
    rcall LED3_ON ; FIXME: DEBUG
    ret
joystick_up:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    ; -- increase BPM
    rcall Incr_BPM_btn
    rcall LED2_ON ; FIXME: DEBUG
    ret

; FIXME: for DEBUG:
joystick_center:
    ; -- reset states
    clr temp ; default joystick state
    sts Prev_JS_Up, temp ; reset prev btn up state to 0 (no btn up)
    sts Prev_JS_Down, temp ; reset prev btn down state to 0 (no btn down)
    sts Prev_JS_Right, temp ; reset prev joystick x state to center
    sts Prev_JS_Left, temp ; reset prev joystick y state to center
    rcall LED2_OFF
    rcall LED3_OFF
    ret

Read_ADC:
    ; input: r18 = ADC channel to read (0-7)
    ; output: r19 = ADC value (0-255)
    push temp

    ; -- set channel
    ; TODO: necessary ?
    andi r18, 0b00001111 ; channel must be 0-15 because MUX3:0 are only 4 bits
    ori r18, (1<<REFS0) | (1<<ADLAR) ; apply reference and left-adjust bits again (see setup)
    sts ADMUX, r18 ; write to ADMUX to set channel (and reference/adjust bits again like in setup)



    ; -- start conversion
    lds temp, ADCSRA ; read current value of ADC Control and Status Register A
    ori temp, (1<<ADSC) ; set the ADC Start Conversion bit
    sts ADCSRA, temp

    Wait_For_ADC:
    ; -- wait for the conversion end
    ; QDC hardware will automatically clear the ADSC bit when done
    lds temp, ADCSRA
    sbrc temp, ADSC ; skip next if ADSC is 0
    rjmp Wait_For_ADC ; loop back up

    ; -- get value result
    lds r19, ADCH ; output (read only the high byte for 8-bit resolution)

    ; restore
    pop temp
    ret
; ===#===

; === Keypad scanning/polling routine step 2 ===
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
    ret ; i guess shoudln't happen
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
    ret ; i guess shoudln't happen

no_kp_pressed:
    ; do something/nothing ?
    ret

col1pressed:
    ; col Y=1
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col1row1,col1row2,col1row3,col1row4 ; macro with args to rjmp to corresponding label
    ; don't happen:
    ret
col2pressed:
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col2row1,col2row2,col2row3,col2row4 ; macro with args to rjmp to corresponding label
    ; don't happen:
    ret
col3pressed:
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col3row1,col3row2,col3row3,col3row4 ; macro with args to rjmp to corresponding label
    ; don't happen:
    ret
col4pressed:
    ;rcall KP_POLLING_2 ; check row X value => in reg `row` after this func call
    KP_POLLING_2 col4row1,col4row2,col4row3,col4row4 ; macro with args to rjmp to corresponding label
    ; don't happen:
    ret

; --- COL 1 ---
col1row1: ; "7"
    ; do something
    ret
col1row2: ; "4"
    ; do something
    ret
col1row3: ; "1"
    ; do something
    ret
col1row4: ; "A"
    ; do something
    ; decrease octave ?
    ; TODO: implement
    ret

; --- COL 2 ---
col2row1: ; "8"
    ; do something
    ret
col2row2: ; "5"
    ; do something
    ret
col2row3: ; "2"
    ; do something
    ret
col2row4: ; "0"
    ; do something
    ; increase octave ?
    ; TODO: implement
    ret

; --- COL 3 ---
col3row1: ; "9"
    ; do something
    ret
col3row2: ; "6"
    ; do something
    ret
col3row3: ; "3"
    ; do something
    ret
col3row4: ; "B"
    ; do something
    ret

; --- COL 4 ---
col4row1: ; "F"
    ; do something
	rcall Incr_BPM_btn ; FIXME: debug
    ret
col4row2: ; "E"
    ; do something
	rcall Decr_BPM_btn ; FIXME: debug
    ret
col4row3: ; "D"
    ; do something
    ret
col4row4: ; "C"
    ; do something
    ; clear/mute note
    ; TODO: implement
    ret
; ===#===

; ; === handle play pause btn ===
; Play_Pause_btn:
;     ; toggle play/pause state
;     ; -- edge detection
;     lds r22, Prev_JS_Click
;     cpi r22, 1 ; was prev state click 1 ?
;     breq Skip_Click_Check ; if state hasn't changed (still click), do nothing
;     ldi r22, 1 ; new state is click 1
;     sts Prev_JS_Click, r22 ; save new state
;     ; ! DON'T FORGET TO SET BACK TO 0 AFTER RELEASED
;     ; -- toggle play/pause state
;     ; TODO: implement
;     rcall Toggle_Play_Pause
;     Skip_Click_Check:
;     ret
; ; ===#===

; === handle manual sequencer steps ===
Next_Step_btn:
    ; advance to next step in sequence
    ; -- edge detection
    lds r22, Prev_JS_Right
    cpi r22, 1 ; was prev state right 1 ?
    breq Skip_Right_Check ; if state hasn't changed (still right), do nothing
    ldi r22, 1 ; new state is right 1
    sts Prev_JS_Right, r22 ; save new state
    ; ! DON'T FORGET TO SET BACK TO 0 AFTER RELEASED
    ; -- increase current step
    ; TODO: implement
    ; ; if we're on last step, loop back to first
    ; lds r23, Step
    ; cpi r23, 31 ; compare with max step idx (31 for 32 steps)
    ; brsh Reset_Step ; if step idx >= 31, reset to 0
    ; inc r23 ; next step
    ; sts Step, r23 ; save new step idx
    ; rjmp End_Next_Step
    ; ; -- loop back to first step
    ; Reset_Step:
    ; clr r23 ; reset to step 0
    ; sts Step, r23
    ; End_Next_Step:

    rcall Next_Step

    Skip_Right_Check:
    ret

Prev_Step_Btn:
    ; move back to previous step in sequence
    ; -- edge detection
    lds r22, Prev_JS_Left
    cpi r22, 1 ; was prev state left 1 ?
    breq Skip_Left_Check ; if state hasn't changed (still left), do nothing
    ldi r22, 1 ; new state is left 1
    sts Prev_JS_Left, r22 ; save new state
    ; ! DON'T FORGET TO SET BACK TO 0 AFTER RELEASED
    ; -- decrease current step
    ; TODO: implement
    ; ; if we're on first step, loop back to last
    ; lds r23, Step
    ; cpi r23, 1 ; compare with min step idx (0, but 1 because < not <=)
    ; brlo Set_Last_Step ; if step idx < 1, set to last step idx
    ; dec r23 ; previous step
    ; sts Step, r23 ; save new step idx
    ; rjmp End_Previous_Step
    ; ; -- loop back to last step
    ; Set_Last_Step:
    ; ldi r23, 31 ; set to last step (31 for 32 steps bc 0-indexed)
    ; sts Step, r23
    ; End_Previous_Step:

    rcall Prev_Step

    Skip_Left_Check:
    ret
; ===#===

; === handle BPM changes from joystick ===
Incr_BPM_btn:
	push temp
	push r17
	push r22

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

    ; -- edge detection
    lds r22, Prev_JS_Up
    cpi r22, 1 ; was prev state up 1 ?
    breq Skip_Up_Check ; if state hasn't changed (still up), do nothing
    ldi r22, 1 ; new state is up 1
    sts Prev_JS_Up, r22 ; save new state
    ; ! DON'T FORGET TO SET BACK TO 0 AFTER RELEASED
    ; -- increase BPM
    lds r17, Current_BPM
    cpi r17, 200 ; ComPare Immediate (with max BPM=200)
    brsh Incr_BPM_end ; BRanch if Same or Higher (if BPM >= 200, skip incrementing)
    inc r17
    rcall Update_BPM ; will save it to SRAM
    Incr_BPM_end:
    Skip_Up_Check:

	Incr_BPM_btn:
	Skip_Incr_BPM_btn:
	pop r22
	pop r17
	pop temp
    ret

Decr_BPM_btn:
    ; -- edge detection
    lds r22, Prev_JS_Down
    cpi r22, 1 ; was prev state down 1 ?
    breq Skip_Down_Check ; if state hasn't changed (still down), do nothing
    ldi r22, 1 ; new state is down 1
    sts Prev_JS_Down, r22 ; save new state
    ; ! DON'T FORGET TO SET BACK TO 0 AFTER RELEASED
    ; -- decrease BPM
    lds r17, Current_BPM
    cpi r17, 61 ; ComPare Immediate (with min BPM=60)
    brlo Decr_BPM_end ; BRanch if Lower (if BPM < 61, skip decrementing)
    dec r17
    rcall Update_BPM ; will save it to SRAM
    Decr_BPM_end:
    Skip_Down_Check:
    ret
; ===#===
