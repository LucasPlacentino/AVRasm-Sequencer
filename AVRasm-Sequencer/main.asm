;
; AVRasm-Sequencer.asm :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

; ATmega328P
.include "m328pdef.inc"

; use:
; .org !
; .def
; .equ
; .dw
; .db
; .set
; etc

; the z pointer, ZL and ZH are registers R30 and R31, used as a pointer for flash memory access (lpm instruction)
; the x pointer, XL and XH are registers R26 and R27, used as a pointer for SRAM access (st/ld instructions)

.def temp = r16 ; example: define alias "temp" for the register "r16"
.def px_x = r20 ; Set_Pixel input, x coordinate (0 to 39)
.def px_y = r21 ; Set_Pixel input, y coordinate (0 to 13)
.def px_state = r22 ; Set_Pixel input, LED pixel state (1=ON, 0=OFF)

; === SRAM definitions ===
.dseg ; define data segment for SRAM
.org SRAM_START
; -- main data variables for the sequencer
Sequence: .byte 32 ; 32 bytes for the 32 steps
Step: .byte 1 ; keep traack of step number (0 to 31)
Current_Octave: .byte 1 ; keep track of current octave (0 to 4)
Tick_Counter: .byte 2 ; 16bit counter for milliseconds
Tempo_Delay: .byte 2 ; 16bit delay (in ms) based on BPM, kinda rounded (sufficiently precise)
Current_BPM: .byte 1 ; store current BPM (value between 60 and 200)
Is_Playing: .byte 1 ; boolean to track if the sequencer is currently playing or paused
; -- store previous joystick state (for edge detection)
Prev_JS_Click: .byte 1
Prev_JS_Down: .byte 1
Prev_JS_Up: .byte 1
Prev_JS_Left: .byte 1
Prev_JS_Right: .byte 1
; -- store previous keypad buttons states (for edge detection)
Prev_KP_0: .byte 1
Prev_KP_1: .byte 1
Prev_KP_2: .byte 1
Prev_KP_3: .byte 1
Prev_KP_4: .byte 1
Prev_KP_5: .byte 1
Prev_KP_6: .byte 1
Prev_KP_7: .byte 1
Prev_KP_8: .byte 1
Prev_KP_9: .byte 1
Prev_KP_A: .byte 1
Prev_KP_B: .byte 1
Prev_KP_C: .byte 1
Prev_KP_D: .byte 1
Prev_KP_E: .byte 1
Prev_KP_F: .byte 1
KP_A_Debounce_Counter: .byte 1 ; counter for debouncing octave decr button
KP_0_Debounce_Counter: .byte 1 ; counter for debouncing octave incr button
KP_B_Debounce_Counter: .byte 1 ; counter for debouncing melody change button
; -- display
Screen_Buffer: .byte 560 ; entire screen buffer, 1 led to 1 byte, 80(=40*2) bytes per row * 7 rows = 560
Active_Row: .byte 1 ; Tracks the current screen row (electrically, 0 to 6)

; -- melody selection
Current_Melody_Idx: .byte 1 ; index of the current melody in the melody selection (0 to 7, for 8 melodies)
; preset melodies are in Flash mem
; Preset_Melody_1: .byte 32 ; preset melody 1 (32 steps)
; Preset_Melody_2: .byte 32 ; preset melody 2 (32 steps)
; Preset_Melody_3: .byte 32 ; preset melody 3 (32 steps)
; Preset_Melody_4: .byte 32 ; preset melody 4 (32 steps)
; Preset_Melody_5: .byte 32 ; preset melody 5 (32 steps)
User_Melody_1: .byte 32 ; user melody 1 (32 steps)
User_Melody_2: .byte 32 ; user melody 2 (32 steps)
User_Melody_3: .byte 32 ; user melody 3 (32 steps)
.cseg ; don't forget
; ===#===

; === .orgs ===
.org 0x0000
    rjmp setup

; timer 0 and 2 are 8bit (up to 255), timer 1 is 16 bit (up to 65535)
; use timer 1 for the buzzer sound notes

; timer2 compare match A (for metronome)
.org OC2Aaddr
    rjmp ISR_Metronome ; Timer 2 Compare Match A Vector for the Metronome

; timer0 OVF
.ORG OVF0addr
    RJMP ISR_Display ; Timer 0 Overflow Vector for the Screen Refresh
; ===#===

; === outputs ===
; -- display
.equ DISPLAY_D = DDRb
.equ DISPLAY_PORT = PORTb ; PORTb is used for both setting the data line and clock line of the display, and also for reading the switch input, so be careful to not mess with the other pins when configuring it
.equ DISPLAY_PIN = PINb ; PINb is used for clocking the display and also for reading the switch input, so be careful to not mess with the other pins when configuring it
.equ DISPLAY_DATA_I = 3 ; data line of the display
.equ DISPLAY_CLK_I = 5 ; clock line of the display
.include "display.inc"

; -- LEDs
.equ LED2_D = DDRc
.equ LED2_P = PORTc
.equ LED2_I = 2 ; or PC2
.equ LED3_D = DDRc
.equ LED3_P = PORTc
.equ LED3_I = 3 ; or PC3

; -- buzzer
.equ BZ_D = DDRb
.equ BZ_P = PORTb
.equ BZ_I = 1
; ===#===

; === inputs ===
; -- switch
.equ SW_D = DDRb
.equ SW_P = PORTb ; to set pullup
.equ SW_I = 0
.equ SW_SENSE = PINb ; to read switch state

; -- joystick
.equ JS_BTN_D = DDRb
.equ JS_BTN_P = PORTb ; to set pullup
.equ JS_BTN_I = 2
.equ JS_BTN_SENSE = PINb
; need to use the ADC for the joystick directions
.equ JS_X_D = DDRc
.equ JS_X_I = 0 ; ADCchannel0
.equ JS_Y_D = DDRc
.equ JS_Y_I = 1 ; ADCchannel1

; -- keypad
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

.include "inputs.inc"
; ===#===

.include "defines.inc" ; all the notes timer overeflow declarations etc

; example:
;Play_Note_C4:
;    ; CRITICAL: in AVR asm must write  HIGH byte of a 16-bit register first, then the LOW byte. the hardware latches it.
;    ldi temp, high(NOTE_C4)
;    sts OCR1AH, temp
;    ldi temp, low(NOTE_C4)
;    sts OCR1AL, temp
;
;    ; ; ensure the timer is connected to the pin (un-mute)
;    ; ldi temp, (1<<COM1A0)
;    ; sts TCCR1A, temp
;    ret


; === play the note from r17 (input), byte is index of note, 0x00-0x18/0x30 aka 0 to 48, or 0xFF (mute) ===
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
    cpi r17, NB_NOTES ; because 25/49 notes (or 0x19) => .set/.equ above
    brge End_Play_Note ; if index >= 25, skip to end
    ; -- compute byte offset (word is 2 bytes, aka 16bits), 16 bit mult by 2:
    mov r18, r17 ; MOVe lut index to r18 (keep r17 intact)
    clr r19 ; CLeaR r19 for the high byte of the offset
    lsl r18 ; Logical Shift Left (mult r18 by 2) (MSB goes in the Carry Flag (C))
    rol r19 ; ROtate Left thrpugh carry r19, here just pulls the shifted MSB from r18 in the Carry Flag (to handle numbers > 127)

    ; -- set up z pointer: r31(ZH)-r30(ZL) (flash mem is word-based, but `lpm` uses bytes for addresses, need to mult by 2 the note index of the lut)
    ldi ZL, low(Note_Table * 2)
    ldi ZH, high(Note_Table * 2)
    ; -- add offset to z pointer
    add ZL, r18
    adc ZH, r19 ; ADd with Carry for the high byte (ZH = ZH + r19 + Carry_Flag from add above)
    ; -- get data from lut in flash (little endian: low byte first, then high byte last)
    lpm r19, Z+ ; read low byte, then increment Z pointer
    lpm r20, Z ; read high byte

    ; -- write val to timer 1 (high byte written first!)
    sts OCR1AH, r20
    sts OCR1AL, r19

    ; -- check if switch is off (disable sound)
    sbis SW_SENSE, SW_I ; Skip if Bit in I/o reg is Set
    rjmp Note_Mute ; disable sound if input pin of switch is low

    ; -- unmute buzzer
    ldi temp, (1<<COM1A0) ; COM1A1:0 = 01 -> Toggle OC1A on Compare Match (TCCR1A) ; 1<<COM1A0
    sts TCCR1A, temp

    rjmp End_Play_Note ; skip mute part

    Note_Mute:
    ; no note (mute)
    rcall Mute_Buzzer

    End_Play_Note:
    ; -- restore
    pop ZH
    pop ZL
    pop r20
    pop r19
    pop r18

    ret
; ===#===

; === to mute: ===
Mute_Buzzer:
    ; -- disconnect the timer "hardware" from PB1 by clearing COM1A0, this mutes the buzzer
    ldi temp, 0b00 ; COM1A1:0 = 00 -> normal operation (OC1A disconnected) ; just 0
    sts TCCR1A, temp
    ; -- force pin LOW to prevent DC current from damaging the buzzer ?
    cbi BZ_P, BZ_I ; i don't think that's necessary but let's be safe
    ret
; ===#===

; -- Use Timer 2 for the metronome
; 16MHz clock, prescaler at 64 => 250 000 ticks/sec
; for 1ms: (250000 / 1000) - 1 = 249 (into OCR2A)
; let's use a "16th-note" step (whatever that means i'm not a musician)
; target delay is:
; 60000 / (BPM * 4) = Tempo_Delay

; === Update BPM ===
; input r17 is target BPM (must be between 60 and 200 !)
Update_BPM:
    push temp
    push r18
    push r19
    push ZL
    push ZH

    sts Current_BPM, r17 ; store current BPM in SRAM for reference

    ; -- r17 is BPM input for drawing it
    rcall Draw_BPM

    ; -- substract MIB_BPM to get the BPM table idx (0 to 140), because we used BPMs b/w 60 and 200
    subi r17, MIN_BPM

    ; -- mltiply idx by 2 (because .dw uses 2 bytes)
    mov r18, r17 ; MOVe lut index to r18 (keep r17 intact)
    clr r19 ; CLeaR r19 for the high byte of the offset
    lsl r18 ; Logical Shift Left (mult r18 by 2) (MSB goes in the Carry Flag (C))
    rol r19 ; ROtate Left thrpugh carry r19, here just pulls the shifted MSB from r18 in the Carry Flag

    ; -- set z pointer to table origin
    ldi ZL, low(BPM_Table * 2)
    ldi ZH, high(BPM_Table * 2)

    ; -- add the offset to the z pointer
    add ZL, r18
    adc ZH, r19

    ; -- get 16-bit delay value
    lpm r18, Z+ ; read low byte
    lpm r19, Z  ; read high byte

    ; -- safely update the SRAM metronome varq
    ; (to prevent the ISR from reading half a new value while writing it, temporarily disable interrupts)
    cli
    sts Tempo_Delay, r18
    sts Tempo_Delay+1, r19
    sei ; reenable interrupts

    ; restore
    pop ZH
    pop ZL
    pop r19
    pop r18
    pop temp
    ret
; ===#===

; === Setup sequence, runs once on startup ===
setup:
    ; initialize stack pointer (just to be sure), not necessary
    ;ldi temp, high(RAMEND)
    ;out SPH, temp
    ;ldi temp, low(RAMEND)
    ;out SPL, temp

    ; -- init playing state
    ldi temp, 0; default to playing or paused (0:paused, 1:playing) ; TODO: choose which?
    sts Is_Playing, temp ; paused or playing by default (on startup)

    ; ---- Timer 0 (for display) ----
    ; Normal mode, Prescaler = 64 (16MHz / 64 = 250kHz. Overflow at 256 = ~976Hz)
    ldi temp, (1<<CS01) | (1<<CS00) ; prescaler 64
    ;ldi temp, (1<<CS00) ; prescaler 1, just for testing
    ;ldi temp, (1<<CS01) ; prescaler 8, just for testing
    ;ldi temp, (1<<CS02) ; prescaler 256, just for testing
    ;ldi temp, (1<<CS02) | (1<<CS00) ; prescaler 1012, just for testing
    out TCCR0B, temp
    ldi temp, (1<<TOIE0)
    sts TIMSK0, temp

    ; ---- Timer 1 (for notes/sound) ----
    ; -- Configure TCCR1A
    ; COM1A1:0 = 01 -> Toggle OC1A on Compare Match ; 1<<COM1A0
    ; WGM11:0 = 00 -> Lower bits for CTC Mode 4 ; nothing
    ldi temp, (1<<COM1A0)
    sts TCCR1A, temp
    ; -- Configure TCCR1B
    ; WGM13:2 = 01 -> Upper bits for CTC Mode 4 (WGM = 0100) ; 1<<WGM12
    ; ; CS12:0 = 001 -> Prescaler = 1 ; 1<<CS10
    ; CS12:0  = 010 -> Prescaler = 8 (to be able to go to lower octaves) ; 1<<CS11
    ldi temp, (1<<WGM12) | (1<<CS11)
    sts TCCR1B, temp
    ; ----#----

    ; ---- Timer 2 (for BPM/steps) ----
    ; -- Configure TCCR2A
    ; COM2A1:0 = 00 -> Normal port operation, OC2A disconnected ; nothing
    ; WGM21:0 = 10 -> Lower bits for CTC Mode 2 ; 1<<WGM21
    ldi temp, (1<<WGM21)
    sts TCCR2A, temp
    ; -- Configure TCCR2B
    ; WGM22 = 0 -> Upper bit for CTC Mode 2 (WGM = 010) ; nothing
    ; CS22:0 = 100 -> Prescaler = 64 ; 1<<CS22
    ldi temp, (1<<CS22)
    sts TCCR2B, temp
    ; -- Configure TIMSK2 (Timer Interrupt MaSK 2)
    ; OCIE2A = 1 -> Enable Timer 2 Compare Match A Interrupt
    ldi temp, (1<<OCIE2A)
    sts TIMSK2, temp

    ; ; ~~~~~~~~~~
    ; ; DEBUG:
    ; ; ! temporary for testing, set TIMSK2 to 0 to disable buzzer for now
    ; ldi temp, 0
    ; sts TIMSK2, temp
    ; ; ~~~~~~~~~~

    ; -- Configure OCR2A (ceiling value of timer 2)
    ; 16MHz / Prescaler 64 = 250,000 ticks/sec
    ; ; 1ms resolution => 1000Hz
    ; ; 250,000 / 1000Hz = 250 ticks, 0-indexed so 249:
    ; ldi temp, 249
    ; 0.1ms resolution => 10000Hz
    ; 250,000 / 10000Hz = 25 ticks, 0-indexed so 24:
    ldi temp, 24
    sts OCR2A, temp
    ; ----#----

    rcall Inputs_Init ; initialize inputs (switch, joystick, keypad)

    ; ### NOT USED ANYMORE ### using melody selection now
    ; ; -- init sequence in SRAM
    ; rcall Init_Sequence ; clear sequence
    ; ######

    ; -- init melody selection
    rcall Clear_User_Melodies ; clear user melodies in SRAM on startup (fill with 0xFF for mute/blank)
    clr temp ; aka ldi temp, 0
    sts Current_Melody_Idx, temp ; default to melody 0
    mov r17, temp ; r17 is input melody idx for Load_Melody
    rcall Load_Melody ; load default melody into sequence (based on Current_Melody_Idx, which is 0 for now)

    ; -- init step
    ldi temp, 0 ; default step 0
    sts Step, temp ; store default step in SRAM

    ; -- init octave
    ldi temp, 3 ; default octave 1 (0-3)
    sts Current_Octave, temp ; store default octave in SRAM

    ; -- init bpm
    ldi r17, 108 ; default BPM
    rcall Update_BPM ; set BPM (save in SRAM and update Tempo_Delay)

    ; ---- outputs ----
    ; -- screen
    ;! do not "poison" the other pins on the same port (PORTb)
    in temp, DISPLAY_D ; read current DDRb config to not mess with other pins
    ori temp, (1<<DISPLAY_DATA_I) | (1<<4) | (1<<DISPLAY_CLK_I) ; or with display bits
    out DISPLAY_D, temp
    in temp, DISPLAY_PORT ; read current PORTb config to not mess with other pins
    ori temp, (1<<DISPLAY_DATA_I) | (1<<4) | (1<<DISPLAY_CLK_I) ; or with display bits
    out DISPLAY_PORT, temp

    rcall Init_Display

    ; -- buzzer output
    sbi BZ_D,BZ_I ; set buzzer out pin dir to output(1)
    cbi BZ_P,BZ_I ; clear buzzer output to low

    ; -- leds output
    sbi LED2_D,LED2_I ;set led2 out pin dir to output(1)
    cbi LED2_P,LED2_I ;clear led2 to off
    sbi LED3_D,LED3_I ;set led3 out pin dir to output(1)
    cbi LED3_P,LED3_I ;clear led3 to off
    ; ----#----

    rcall Startup_Display ; start the display with initial values shown
    sei ; Set Enable Interrupts
    rjmp loop ; end of setup, jump to main loop
; ===#===

; ; === Clear Sequence (stratup) ===
; Init_Sequence:
;     push ZL
;     push ZH
;     push XL
;     push XH
;     push r17
;     push temp

;     ; -- x pointer to base address of the sequence in SRAM
;     ldi XL, low(Sequence)
;     ldi XH, high(Sequence)

;     ; -- z pointer to base address of the default melody in Flash mem (only z for Flash!)
;     ldi ZL, low(Default_Melody * 2)
;     ldi ZH, high(Default_Melody * 2)

;     ; ; load rest/mute value
;     ; ldi temp, 0xFF ; 0xFF means mute, DEBUG: for testing

;     ; ; DEBUG:
;     ; ldi temp, 33 ; NOTE_A3 is idx 33, A (3rd octave), DEBUG: for testing

;     ; set below loop duration to the 32 steps
;     ldi r17, 32
;     Fill_Sequence:
;     ; ; store rest/mute value in sequence and auto-increment z pointer to next byte in SRAM
;     ; st X+, temp
;     ; ; decr counter and loop if not zero
;     ; dec r17
;     ; brne Fill_Sequence
;     ; ; Sequence is initialized with all mutes/rests

;     ; -- fill sequence with default melody from flash mem
;     lpm temp, Z+ ; load note index from default melody
;     st X+, temp ; store note index into Sequence
;     dec r17
;     brne Fill_Sequence
;     ; Sequence is initialized with the default melody

;     ; -- restore
;     pop temp
;     pop r17
;     pop XH
;     pop XL
;     pop ZH
;     pop ZL
;     ret
; ; ===#===

; === Clear user melodies on startup ===
Clear_User_Melodies:
    push YL
    push YH
    push temp
    push r18

    ldi YL, low(User_Melody_1)
    ldi YH, high(User_Melody_1)
    ldi r18, 128 ; 4 melodies * 32 bytes each
    ldi temp, 0xFF ; mute/blank note

    Clear_User_Loop:
    st Y+, temp
    dec r18
    brne Clear_User_Loop

    pop r18
    pop temp
    pop YH
    pop YL
    ret
; ===#===

; === loading a preset melody ===
; input r17 (melody index 0-7)
;   0-4 = Preset_Melody_1 through 5
;   5-7 = User_Melody_1 through 3
; load 32 bytes from selected melody into active Sequence
Load_Melody:
    push ZL
    push ZH
    push YL
    push YH
    push temp
    push r18

    ; -- DEBUG:
    rcall LED2_ON

    ; -- save current melody before loading new one (if user melody)
    push r17 ; save function input
    lds r17, Current_Melody_Idx
    rcall Save_Melody
    pop r17 ; restore function input

    ; -- save melody index
    sts Current_Melody_Idx, r17

    ; -- calculate source address based on melody index
    cpi r17, 5
    brlo Load_Preset_Melody ; if index < 5 it's a preset


    Load_User_Melody:
    subi r17, 5 ; adjust to 0-2 for offset calc
    ldi ZL, low(User_Melody_1)
    ldi ZH, high(User_Melody_1)
    rjmp Compute_Melody_Offset

    Load_Preset_Melody:
    ; preset melody (index 0-4)
    ldi ZL, low(Preset_Melody_1 * 2) ; flash mem is word-addressed but lpm uses byte addresses, so need to mult by 2 the base address for the first preset melody
    ldi ZH, high(Preset_Melody_1 * 2) ; flash mem is word-addressed but lpm uses byte addresses, so need to mult by 2 the base address for the first preset melody

    Compute_Melody_Offset:
    ; each melody is 32 bytes, so offset = index * 32
    ldi temp, 32
    mul r17, temp
    add ZL, r0 ; add low byte of result (mult result is in r1:r0)
    adc ZH, r1 ; add high byte with carry

    ; -- copy 32 bytes from source (z) to Sequence (y)
    ldi YL, low(Sequence)
    ldi YH, high(Sequence)
    ldi r18, 32 ; counter for the loop over the 32 bytes

    Copy_Melody_Loop:
    ; check which source we're copying from (user: SRAM, preset: Flash)
    lds temp, Current_Melody_Idx
    cpi temp, 5
    brlo Copy_From_Flash
    
    Copy_From_SRAM:
    ld temp, Z+ ; SRAM: use ld
    rjmp Store_Byte

    Copy_From_Flash:
    lpm temp, Z+ ; FLASH: use lpm
    
    Store_Byte:
    st Y+, temp
    dec r18
    brne Copy_Melody_Loop

    ; -- refresh display to show new melody
    rcall Draw_Sequence
    rcall Draw_Melody_Indicator

    ; -- restore
    pop r18
    pop temp
    pop YH
    pop YL
    pop ZH
    pop ZL
    ret
; ===#===

; === Save user melody to SRAM ===
; input r17 (melody index 0-7, only saves if 4-7)
; saves current Sequence to the user melody slot
Save_Melody:
    push ZL
    push ZH
    push YL
    push YH
    push temp
    push r18

    ; -- if index < 5, it's a preset, skip save
    cpi r17, 5
    brlo End_Save_Melody

    ; -- it's a user melody (5-7)
    subi r17, 5 ; adjust to 0-2 for offset calc
    ldi ZL, low(User_Melody_1)
    ldi ZH, high(User_Melody_1)

    ; -- calculate offset for z pointer
    ldi temp, 32
    mul r17, temp
    add ZL, r0
    adc ZH, r1
    
    ; -- copy Sequence to the user melody slot in SRAM
    ldi YL, low(Sequence)
    ldi YH, high(Sequence)
    ldi r18, 32
    
    Copy_Seq_To_Melody:
    ld temp, Y+
    st Z+, temp
    dec r18
    brne Copy_Seq_To_Melody ; loop until all 32 bytes copied

    End_Save_Melody:
    pop r18
    pop temp
    pop YH
    pop YL
    pop ZH
    pop ZL
    ret
; ===#===

; === infinite main loop (right after setup) ===
loop:

    rjmp User_Inputs ; handle user inputs (joystick, keypad) ; rjmp! (no ret in it)

    rjmp loop ; doesnt really happen (rjmp loop at end of User_Inputs)
; ===#===

; === Metronome's ISR ===
ISR_Metronome: ; called every time timer 2 reaches OCR2A (every (1ms or) 0.1ms)
    push r16 ; aka temp
    push r17
    push r18
    push r19
    push ZL
    push ZH
    in temp, SREG ; in ISR: save status register to temp to preserve the global interrupt flag (for nested interrupts), and also other flags if needed
    push temp

    ; -- incr 16-bit Tick Counter
    lds r16, Tick_Counter
    lds r17, Tick_Counter+1
    subi r16, low(-1) ; add 1 to low byte
    sbci r17, high(-1) ; add carry (from low byte) to high byte
    sts Tick_Counter, r16
    sts Tick_Counter+1, r17

    ; -- reset btn states (joystick and keypad) every 200ms
    ; if Tick Counter == 2000 (for 0.1ms)
    mov r18, r16 ; copy low byte of Tick Counter to r18 for comparison
    mov r19, r17 ; copy high byte of Tick Counter to r19 for comparison
    subi r18, low(5000) ; 2000 for 0.1ms resolution = 200ms
    sbci r19, high(5000) ; sub with carry for high byte
    ;brne Skip_Reset_Btn_States ; if not 200ms yet, skip reset ; fixed below
    brlo Skip_Reset_Btn_States ; if not 200ms yet, skip reset
    rcall Reset_Prev_Btn_States
    Skip_Reset_Btn_States:

    ; -- compare with Tempo_Delay (e.g. 1249 is 120 BPM)
    lds ZL, Tempo_Delay
    lds ZH, Tempo_Delay+1
    cp r16, ZL
    cpc r17, ZH
    ;brne End_ISR_Metronome ; if delay not reached: exit ; fixed below
    brlo End_ISR_Metronome ; if delay not reached: exit

    ; -- delay reached: reset Tick Counter to 0
    clr temp ; aka ldi temp,0
    sts Tick_Counter, temp
    sts Tick_Counter+1, temp

    ; -- skip playing the note if paused
    ; yeah keep running the Metronome even during pause to keep the timing, just skip the note-playing part
    lds temp, Is_Playing
    sbrs temp, 0 ; Skip if Bit in Register Set (first bit is 0 if paused, 1 if playing)
    rjmp End_ISR_Metronome ; do not advance step when paused ?

    ; -- play note for current step
    lds r17, Step ; get current step index
    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)
    clr temp ; clear temp for high byte addition
    add ZL, r17 ; add step index to z pointer to point to current step's note in sequence
    adc ZH, temp ; add carry to high byte (ZH) from low byte addition
    ld r17, Z ; load current step's note index into r17
    rcall Play_Note ; play the note for the current step (r17 is input idx)

    ;End_Sequence_Play_Note: ; not used anymore

    ; -- advance sequencer step
    rcall Next_Step
    rcall Draw_Step

    End_ISR_Metronome:
    ; -- restore stack
    pop temp
    out SREG, temp
    pop ZH
    pop ZL
    pop r19
    pop r18
    pop r17
    pop r16
    reti
; ===#===

; === step control ===
Next_Step:
    ; advance sequencer step
    lds temp, Step
    ; -- check if at end of sequence (32 steps), loop back to 0
    cpi temp, 31
    brsh Loop_To_Start_Next_Step

    inc temp ; next step
    sts Step, temp
    rjmp End_Next_Step

    Loop_To_Start_Next_Step:
    clr temp ; aka ldi temp,0
    sts Step, temp

    End_Next_Step:
    rcall Reset_Prev_KP_States ; DO NOT RESET JS STATE
    ret

Prev_Step:
    ; move to previous step
    lds temp, Step
    ; -- check if at start of sequence (step 0), loop back to end (31)
    cpi temp, 1
    brlo Loop_To_End_Prev_Step

    dec temp ; previous step
    sts Step, temp
    rjmp End_Prev_Step

    Loop_To_End_Prev_Step:
    ldi temp, 31
    sts Step, temp

    End_Prev_Step:
    rcall Reset_Prev_KP_States ; DO NOT RESET JS STATE
    ret
; ===#===

; === led outputs helper functions ===
LED2_ON:
    ; LOW enable
    cbi LED2_P,LED2_I ;set bit of led to low
    ret
LED2_OFF:
    ; HIGH disable
    sbi LED2_P,LED2_I ;set bit of led to high
    ret
LED3_ON:
    ; LOW enable
    cbi LED3_P,LED3_I ;set bit of led to low
    ret
LED3_OFF:
    ; HIGH disable
    sbi LED3_P,LED3_I ;set bit of led to high
    ret
; ===#===

