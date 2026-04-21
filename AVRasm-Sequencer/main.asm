;
; AVRasm-Sequencer.asm :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

; ATmega328P
.include "m328pdef.inc"

; TODO: use some of these ?
; .ORG
; .DEF
; .EQU
; .DW
; .SET

.def temp = r16 ; example: define alias "temp" for the register "r16"
.def px_x = r20 ; Set_Pixel input: X coordinate (0 to 79)
.def px_y = r21 ; Set_Pixel input: Y coordinate (0 to 6)
.def px_state = r22 ; Set_Pixel input: State (1=ON, 0=OFF)

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
; Screen_Buffer: .byte 70 ; 10 bytes per row * 7 rows (LED diplay) -> 1 bit per LED
;Screen_Buffer: .byte 560 ; 80(40*2) bytes per row * 7 rows (LED display) -> 1 byte per LED ; set in display.asm file
Screen_Buffer: .byte 560 ; entire screen buffer, 1 led to 1 byte
Active_Row: .byte 1 ; Tracks the current screen row (electrically, 0 to 6)
.cseg

; timer 0 and 2 are 8bit (up to 255), timer 1 is 16 bit (up to 65535)

.org 0x0000
    rjmp setup

; timer2 OVF
.org OC2Aaddr ; timer 2 overflow interrrupt vector
    rjmp ISR_Metronome

; timer0 OVF
.ORG OVF0addr
    RJMP ISR_Display ; Timer 0 Overflow Vector for the Screen Refresh

; use timer 1 for the buzzer sound notes

; === display ===
.equ DISPLAY_D      = DDRB
.equ DISPLAY_PORT     = PORTB
.equ DISPLAY_PIN      = PINB
.equ DISPLAY_DATA     = 3
.equ DISPLAY_CLK      = 5
.include "display.asm"
; ===#===

; -- LEDs
.equ LED2_D = DDRc
.equ LED2_P = PORTc
.equ LED2_I = 2 ; or PC2
.equ LED3_D = DDRc
.equ LED3_P = PORTc
.equ LED3_I = 3 ; or PC3

; ;buzzer
; .equ BZ_OUT_DIR = DDRb
; .equ BZ_OUT_BANK = PORTb
; .equ BZ_OUT_IDX = 1
; .equ BZ_OUT_PIN_TGL = PINb ; PINxn is PORTxn no need for DDRx for toggling
; ; we can just do SBI PINb,1 to toggle the buzzer pin
; .equ BZ_PORT = PORTb
; .equ BZ_TGL_PIN = PINb

; -- buzzer
.equ BZ_P = PORTb
.equ BZ_I = 1

; === inputs ===
; -- switch
.equ SW_D = DDRb
.equ SW_P = PORTb ; to set pullup
.equ SW_I = 0
.equ SW_SENSE = PINb

; -- joystick
; TODO: how to handle the 4 directions?
.equ JS_BTN_D = DDRb
.equ JS_BTN_P = PORTb ; to set pullup
.equ JS_BTN_I = 2
.equ JS_BTN_SENSE = PINb
; need to use the ADC for the joystick directions
.equ JS_X_D = DDRc
.equ JS_X_I = 0 ; ADC0
.equ JS_Y_D = DDRc
.equ JS_Y_I = 1 ; ADC1

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

.include "inputs.asm"
; ===#===

; ; %%%%%%%%%%%%%%%%%% OLD %%%%%%%%%%%%%%%%%%
; ; Timer1 reset value for overflow timing
; ; tcnt1 = 65536 - round(16MHz/(2*freq_sound))
; ; e.g: .equ TCNT1_RESET_880 = 47354  ;440Hz (880Hz because toggle) ? A
; .equ TCNT1_RESET_C4 = 34958 ; 261.63 Hz
; .equ TCNT1_RESET_CS4 = 36674 ; 277.18 Hz (C#)
; .equ TCNT1_RESET_D4 = 38294 ; 293.66 Hz
; .equ TCNT1_RESET_DS4 = 39823 ; 311.13 Hz (D#)
; .equ TCNT1_RESET_E4 = 41267 ; 329.63 Hz
; .equ TCNT1_RESET_F4 = 42628 ; 349.23 Hz
; .equ TCNT1_RESET_FS4 = 43914 ; 369.99 Hz (F#)
; .equ TCNT1_RESET_G4 = 45128 ; 392.00 Hz
; .equ TCNT1_RESET_GS4 = 46273 ; 415.30 Hz (G#)
; .equ TCNT1_RESET_A4 = 47354 ; 440.00 Hz
; .equ TCNT1_RESET_AS4 = 48375 ; 466.16 Hz (A#)
; .equ TCNT1_RESET_B4 = 49338 ; 493.88 Hz
; .equ TCNT1_RESET_C5 = 50247 ; 523.25 Hz
; ; --- OCR1A values for each note (prescaler of 1):
; ; TODO: verify values in practice
; .equ NOTE_C3 = 61156 ; 130.81 Hz
; .equ NOTE_CS3 = 57723 ; 138.59 Hz (C#)
; .equ NOTE_D3 = 54484 ; 146.83 Hz
; .equ NOTE_DS3 = 51426 ; 155.56 Hz (D#)
; .equ NOTE_E3 = 48540 ; 164.81 Hz
; .equ NOTE_F3 = 45815 ; 174.61 Hz
; .equ NOTE_FS3 = 43242 ; 185.00 Hz (F#)
; .equ NOTE_G3 = 40815 ; 196.00 Hz
; .equ NOTE_GS3 = 38525 ; 207.65 Hz (G#)
; .equ NOTE_A3 = 36363 ; 220.00 Hz ---------
; .equ NOTE_AS3 = 34322 ; 233.08 Hz (A#)
; .equ NOTE_B3 = 32396 ; 246.94 Hz
; ; --- 12 notes in an octave ; i could only use 12 notes so the bottom 4 keys are for other features
; ; maybe use bottom first two keys to change octave ?
; .equ NOTE_C4 = 30577 ; 261.63 Hz
; ; or stop here ? to get only one octave but keep 3 buttons for other stuff ?
; .equ NOTE_CS4 = 28861 ; 277.18 Hz (C#)
; .equ NOTE_D4 = 27241 ; 293.66 Hz
; .equ NOTE_DS4 = 25712 ; 311.13 Hz (D#)
; ; that's 16 notes, too much ?
; .equ NOTE_E4 = 24269 ; 329.63 Hz
; .equ NOTE_F4 = 22907 ; 349.23 Hz
; .equ NOTE_FS4 = 21621 ; 369.99 Hz (F#)
; .equ NOTE_G4 = 20407 ; 392.00 Hz
; .equ NOTE_GS4 = 19262 ; 415.30 Hz (G#)
; .equ NOTE_A4 = 18181 ; 440.00 Hz ---------
; .equ NOTE_AS4 = 17160 ; 466.16 Hz (A#)
; .equ NOTE_B4 = 16197 ; 493.88 Hz
; ; ---
; .equ NOTE_C5 = 15288 ; 523.25 Hz
; ; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

; TODO: use CTC mdoe ? (clear timer on compare match)
; load value into OCR1A
; automatically resets timer and toggles pin (COM1A0 = 1) on the clock edge, it's more precise for slightly better sound
; buzzer needs to be connected to OC1A pin (PB1), it is thanks!!
; ocr1a = (16MHz / (2*N*freq_sound)) - 1
; where N is the prescaler
; === OCR1A values for each note (prescaler = 8): ===
; generated this using excel:
; --- 1st Octave ---
.equ NOTE_C1 = 30577 ; 32.70 Hz
.equ NOTE_CS1 = 28861 ; 34.65 Hz
.equ NOTE_D1 = 27241 ; 36.71 Hz
.equ NOTE_DS1 = 25712 ; 38.89 Hz
.equ NOTE_E1 = 24269 ; 41.20 Hz
.equ NOTE_F1 = 22907 ; 43.65 Hz
.equ NOTE_FS1 = 21621 ; 46.25 Hz
.equ NOTE_G1 = 20407 ; 49.00 Hz
.equ NOTE_GS1 = 19262 ; 51.91 Hz
.equ NOTE_A1 = 18181 ; 55.00 Hz
.equ NOTE_AS1 = 17160 ; 58.27 Hz
.equ NOTE_B1 = 16197 ; 61.74 Hz
; --- 2nd Octave ---
.equ NOTE_C2 = 15288 ; 65.41 Hz
.equ NOTE_CS2 = 14430 ; 69.30 Hz
.equ NOTE_D2 = 13620 ; 73.42 Hz
.equ NOTE_DS2 = 12855 ; 77.78 Hz
.equ NOTE_E2 = 12134 ; 82.41 Hz
.equ NOTE_F2 = 11453 ; 87.31 Hz
.equ NOTE_FS2 = 10810 ; 92.50 Hz
.equ NOTE_G2 = 10203; 98.00 Hz
.equ NOTE_GS2 = 9630 ; 103.83 Hz
.equ NOTE_A2 = 9090 ; 110.00 Hz
.equ NOTE_AS2 = 8579 ; 116.54 Hz
.equ NOTE_B2 = 8098 ; 123.47 Hz
; --- 3rd Octave ---
.equ NOTE_C3 = 7644 ; 130.81 Hz
.equ NOTE_CS3 = 7214 ; 138.59 Hz
.equ NOTE_D3 = 6809 ; 146.83 Hz
.equ NOTE_DS3 = 6427 ; 155.56 Hz
.equ NOTE_E3 = 6067 ; 164.81 Hz
.equ NOTE_F3 = 5726 ; 174.61 Hz
.equ NOTE_FS3 = 5404 ; 185.00 Hz
.equ NOTE_G3 = 5101 ; 196.00 Hz
.equ NOTE_GS3 = 4815 ; 207.65 Hz
.equ NOTE_A3 = 4544 ; 220.00 Hz
.equ NOTE_AS3 = 4289 ; 233.08 Hz
.equ NOTE_B3 = 4049 ; 246.94 Hz
; --- 4th Octave ---
.equ NOTE_C4 = 3822 ; 261.63 Hz
.equ NOTE_CS4 = 3607 ; 277.18 Hz
.equ NOTE_D4 = 3404 ; 293.66 Hz
.equ NOTE_DS4 = 3213 ; 311.13 Hz
.equ NOTE_E4 = 3033 ; 329.63 Hz
.equ NOTE_F4 = 2862 ; 349.23 Hz
.equ NOTE_FS4 = 2702 ; 369.99 Hz
.equ NOTE_G4 = 2550 ; 392.00 Hz
.equ NOTE_GS4 = 2407 ; 415.30 Hz
.equ NOTE_A4 = 2271 ; 440.00 Hz
.equ NOTE_AS4 = 2144 ; 466.16 Hz
.equ NOTE_B4 = 2024 ; 493.88 Hz
; ; --- 5th Octave ---
; .equ NOTE_C5 = 1910 ; 523.25 Hz

.equ NB_NOTES = 48 ;
; ===#===

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


; === Notes LUT ===
; to play a sound, load the note index into a reg (r17), then using a LUT to get the correct value to put in ocr1a ? rather than too many branches
; store this LUT in the flash mem:
; 49 notes (idx 0 to 48)
Note_Table:
; .dw is define word(s)
    ; --- octave 1 (idx 0 to 11) ---
    .dw NOTE_C1, NOTE_CS1, NOTE_D1, NOTE_DS1
    .dw NOTE_E1, NOTE_F1, NOTE_FS1, NOTE_G1
    .dw NOTE_GS1, NOTE_A1, NOTE_AS1, NOTE_B1
    ; --- octave 2 (ixd 12 to 23) ---
    .dw NOTE_C2, NOTE_CS2, NOTE_D2, NOTE_DS2
    .dw NOTE_E2, NOTE_F2, NOTE_FS2, NOTE_G2
    .dw NOTE_GS2, NOTE_A2, NOTE_AS2, NOTE_B2
    ; --- octave 3 (idx 24 to 35) ---
    .dw NOTE_C3, NOTE_CS3, NOTE_D3, NOTE_DS3
    .dw NOTE_E3, NOTE_F3, NOTE_FS3, NOTE_G3
    .dw NOTE_GS3, NOTE_A3, NOTE_AS3, NOTE_B3
    ; --- octave 4 (idx 36 to 47) ---
    .dw NOTE_C4, NOTE_CS4, NOTE_D4, NOTE_DS4
    .dw NOTE_E4, NOTE_F4, NOTE_FS4, NOTE_G4
    .dw NOTE_GS4, NOTE_A4, NOTE_AS4, NOTE_B4
;    ; --- octave 5 (idx 48) ---
;    .dw NOTE_C5
; 0xFF will be no sound
; ===#===


; ; ==== BPM LUT (1ms res) ===
; ; BPM to ms Delay LUT ("16th" notes), rounded
; ; idx 0 = 60 BPM, idx 1 = 61 BPM ...etc... idx 140 = 200 BPM
; ; (60,000/(4*BPM) = delay)
; ; generated this using excel:
; BPM_Table:
;     .dw 249 ; 60 BPM
;     .dw 245 ; 61 BPM
;     .dw 241 ; 62 BPM
;     .dw 237 ; 63 BPM
;     .dw 233 ; 64 BPM
;     .dw 230 ; 65 BPM
;     .dw 226 ; 66 BPM
;     .dw 223 ; 67 BPM
;     .dw 220 ; 68 BPM
;     .dw 216 ; 69 BPM
;     .dw 213 ; 70 BPM
;     .dw 210 ; 71 BPM
;     .dw 207 ; 72 BPM
;     .dw 204 ; 73 BPM
;     .dw 202 ; 74 BPM
;     .dw 199 ; 75 BPM
;     .dw 196 ; 76 BPM
;     .dw 194 ; 77 BPM
;     .dw 191 ; 78 BPM
;     .dw 189 ; 79 BPM
;     .dw 187 ; 80 BPM
;     .dw 184 ; 81 BPM
;     .dw 182 ; 82 BPM
;     .dw 180 ; 83 BPM
;     .dw 178 ; 84 BPM
;     .dw 175 ; 85 BPM
;     .dw 173 ; 86 BPM
;     .dw 171 ; 87 BPM
;     .dw 169 ; 88 BPM
;     .dw 168 ; 89 BPM
;     .dw 166 ; 90 BPM
;     .dw 164 ; 91 BPM
;     .dw 162 ; 92 BPM
;     .dw 160 ; 93 BPM
;     .dw 159 ; 94 BPM
;     .dw 157 ; 95 BPM
;     .dw 155 ; 96 BPM
;     .dw 154 ; 97 BPM
;     .dw 152 ; 98 BPM
;     .dw 151 ; 99 BPM
;     .dw 149 ; 100 BPM
;     .dw 148 ; 101 BPM
;     .dw 146 ; 102 BPM
;     .dw 145 ; 103 BPM
;     .dw 143 ; 104 BPM
;     .dw 142 ; 105 BPM
;     .dw 141 ; 106 BPM
;     .dw 139 ; 107 BPM
;     .dw 138 ; 108 BPM
;     .dw 137 ; 109 BPM
;     .dw 135 ; 110 BPM
;     .dw 134 ; 111 BPM
;     .dw 133 ; 112 BPM
;     .dw 132 ; 113 BPM
;     .dw 131 ; 114 BPM
;     .dw 129 ; 115 BPM
;     .dw 128 ; 116 BPM
;     .dw 127 ; 117 BPM
;     .dw 126 ; 118 BPM
;     .dw 125 ; 119 BPM
;     .dw 124 ; 120 BPM
;     .dw 123 ; 121 BPM
;     .dw 122 ; 122 BPM
;     .dw 121 ; 123 BPM
;     .dw 120 ; 124 BPM
;     .dw 119 ; 125 BPM
;     .dw 118 ; 126 BPM
;     .dw 117 ; 127 BPM
;     .dw 116 ; 128 BPM
;     .dw 115 ; 129 BPM
;     .dw 114 ; 130 BPM
;     .dw 114 ; 131 BPM
;     .dw 113 ; 132 BPM
;     .dw 112 ; 133 BPM
;     .dw 111 ; 134 BPM
;     .dw 110 ; 135 BPM
;     .dw 109 ; 136 BPM
;     .dw 108 ; 137 BPM
;     .dw 108 ; 138 BPM
;     .dw 107 ; 139 BPM
;     .dw 106 ; 140 BPM
;     .dw 105 ; 141 BPM
;     .dw 105 ; 142 BPM
;     .dw 104 ; 143 BPM
;     .dw 103 ; 144 BPM
;     .dw 102 ; 145 BPM
;     .dw 102 ; 146 BPM
;     .dw 101 ; 147 BPM
;     .dw 100 ; 148 BPM
;     .dw 100 ; 149 BPM
;     .dw 99 ; 150 BPM
;     .dw 98 ; 151 BPM
;     .dw 98 ; 152 BPM
;     .dw 97 ; 153 BPM
;     .dw 96 ; 154 BPM
;     .dw 96 ; 155 BPM
;     .dw 95 ; 156 BPM
;     .dw 95 ; 157 BPM
;     .dw 94 ; 158 BPM
;     .dw 93 ; 159 BPM
;     .dw 93 ; 160 BPM
;     .dw 92 ; 161 BPM
;     .dw 92 ; 162 BPM
;     .dw 91 ; 163 BPM
;     .dw 90 ; 164 BPM
;     .dw 90 ; 165 BPM
;     .dw 89 ; 166 BPM
;     .dw 89 ; 167 BPM
;     .dw 88 ; 168 BPM
;     .dw 88 ; 169 BPM
;     .dw 87 ; 170 BPM
;     .dw 87 ; 171 BPM
;     .dw 86 ; 172 BPM
;     .dw 86 ; 173 BPM
;     .dw 85 ; 174 BPM
;     .dw 85 ; 175 BPM
;     .dw 84 ; 176 BPM
;     .dw 84 ; 177 BPM
;     .dw 83 ; 178 BPM
;     .dw 83 ; 179 BPM
;     .dw 82 ; 180 BPM
;     .dw 82 ; 181 BPM
;     .dw 81 ; 182 BPM
;     .dw 81 ; 183 BPM
;     .dw 81 ; 184 BPM
;     .dw 80 ; 185 BPM
;     .dw 80 ; 186 BPM
;     .dw 79 ; 187 BPM
;     .dw 79 ; 188 BPM
;     .dw 78 ; 189 BPM
;     .dw 78 ; 190 BPM
;     .dw 78 ; 191 BPM
;     .dw 77 ; 192 BPM
;     .dw 77 ; 193 BPM
;     .dw 76 ; 194 BPM
;     .dw 76 ; 195 BPM
;     .dw 76 ; 196 BPM
;     .dw 75 ; 197 BPM
;     .dw 75 ; 198 BPM
;     .dw 74 ; 199 BPM
;     .dw 74 ; 200 BPM
; ; ===#===

; ==== BPM LUT (0.1ms res) ===
; BPM to ms Delay LUT ("16th" notes), rounded
; idx 0 = 60 BPM, idx 1 = 61 BPM ...etc... idx 140 = 200 BPM
; (600,000/(4*BPM) = delay)
; generated this using excel:
BPM_Table:
    .dw 2499 ; 60 BPM
    .dw 2458 ; 61 BPM
    .dw 2418 ; 62 BPM
    .dw 2380 ; 63 BPM
    .dw 2343 ; 64 BPM
    .dw 2307 ; 65 BPM
    .dw 2272 ; 66 BPM
    .dw 2238 ; 67 BPM
    .dw 2205 ; 68 BPM
    .dw 2173 ; 69 BPM
    .dw 2142 ; 70 BPM
    .dw 2112 ; 71 BPM
    .dw 2082 ; 72 BPM
    .dw 2054 ; 73 BPM
    .dw 2026 ; 74 BPM
    .dw 1999 ; 75 BPM
    .dw 1973 ; 76 BPM
    .dw 1947 ; 77 BPM
    .dw 1922 ; 78 BPM
    .dw 1898 ; 79 BPM
    .dw 1874 ; 80 BPM
    .dw 1851 ; 81 BPM
    .dw 1828 ; 82 BPM
    .dw 1806 ; 83 BPM
    .dw 1785 ; 84 BPM
    .dw 1764 ; 85 BPM
    .dw 1743 ; 86 BPM
    .dw 1723 ; 87 BPM
    .dw 1704 ; 88 BPM
    .dw 1684 ; 89 BPM
    .dw 1666 ; 90 BPM
    .dw 1647 ; 91 BPM
    .dw 1629 ; 92 BPM
    .dw 1612 ; 93 BPM
    .dw 1595 ; 94 BPM
    .dw 1578 ; 95 BPM
    .dw 1562 ; 96 BPM
    .dw 1545 ; 97 BPM
    .dw 1530 ; 98 BPM
    .dw 1514 ; 99 BPM
    .dw 1499 ; 100 BPM
    .dw 1484 ; 101 BPM
    .dw 1470 ; 102 BPM
    .dw 1455 ; 103 BPM
    .dw 1441 ; 104 BPM
    .dw 1428 ; 105 BPM
    .dw 1414 ; 106 BPM
    .dw 1401 ; 107 BPM
    .dw 1388 ; 108 BPM
    .dw 1375 ; 109 BPM
    .dw 1363 ; 110 BPM
    .dw 1350 ; 111 BPM
    .dw 1338 ; 112 BPM
    .dw 1326 ; 113 BPM
    .dw 1315 ; 114 BPM
    .dw 1303 ; 115 BPM
    .dw 1292 ; 116 BPM
    .dw 1281 ; 117 BPM
    .dw 1270 ; 118 BPM
    .dw 1260 ; 119 BPM
    .dw 1249 ; 120 BPM
    .dw 1239 ; 121 BPM
    .dw 1229 ; 122 BPM
    .dw 1219 ; 123 BPM
    .dw 1209 ; 124 BPM
    .dw 1199 ; 125 BPM
    .dw 1189 ; 126 BPM
    .dw 1180 ; 127 BPM
    .dw 1171 ; 128 BPM
    .dw 1162 ; 129 BPM
    .dw 1153 ; 130 BPM
    .dw 1144 ; 131 BPM
    .dw 1135 ; 132 BPM
    .dw 1127 ; 133 BPM
    .dw 1118 ; 134 BPM
    .dw 1110 ; 135 BPM
    .dw 1102 ; 136 BPM
    .dw 1094 ; 137 BPM
    .dw 1086 ; 138 BPM
    .dw 1078 ; 139 BPM
    .dw 1070 ; 140 BPM
    .dw 1063 ; 141 BPM
    .dw 1055 ; 142 BPM
    .dw 1048 ; 143 BPM
    .dw 1041 ; 144 BPM
    .dw 1033 ; 145 BPM
    .dw 1026 ; 146 BPM
    .dw 1019 ; 147 BPM
    .dw 1013 ; 148 BPM
    .dw 1006 ; 149 BPM
    .dw 999 ; 150 BPM
    .dw 992 ; 151 BPM
    .dw 986 ; 152 BPM
    .dw 979 ; 153 BPM
    .dw 973 ; 154 BPM
    .dw 967 ; 155 BPM
    .dw 961 ; 156 BPM
    .dw 954 ; 157 BPM
    .dw 948 ; 158 BPM
    .dw 942 ; 159 BPM
    .dw 937 ; 160 BPM
    .dw 931 ; 161 BPM
    .dw 925 ; 162 BPM
    .dw 919 ; 163 BPM
    .dw 914 ; 164 BPM
    .dw 908 ; 165 BPM
    .dw 903 ; 166 BPM
    .dw 897 ; 167 BPM
    .dw 892 ; 168 BPM
    .dw 887 ; 169 BPM
    .dw 881 ; 170 BPM
    .dw 876 ; 171 BPM
    .dw 871 ; 172 BPM
    .dw 866 ; 173 BPM
    .dw 861 ; 174 BPM
    .dw 856 ; 175 BPM
    .dw 851 ; 176 BPM
    .dw 846 ; 177 BPM
    .dw 842 ; 178 BPM
    .dw 837 ; 179 BPM
    .dw 832 ; 180 BPM
    .dw 828 ; 181 BPM
    .dw 823 ; 182 BPM
    .dw 819 ; 183 BPM
    .dw 814 ; 184 BPM
    .dw 810 ; 185 BPM
    .dw 805 ; 186 BPM
    .dw 801 ; 187 BPM
    .dw 797 ; 188 BPM
    .dw 793 ; 189 BPM
    .dw 788 ; 190 BPM
    .dw 784 ; 191 BPM
    .dw 780 ; 192 BPM
    .dw 776 ; 193 BPM
    .dw 772 ; 194 BPM
    .dw 768 ; 195 BPM
    .dw 764 ; 196 BPM
    .dw 760 ; 197 BPM
    .dw 757 ; 198 BPM
    .dw 753 ; 199 BPM
    .dw 749 ; 200 BPM
; ===#===

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
; ===#===

; === to mute: ===
Mute_Buzzer:
    ; disconnect the timer "hardware" from PB1 by clearing COM1A0, this mutes the buzzer
    ldi temp, 0b00 ; COM1A1:0 = 00 -> normal operation (OC1A disconnected) ; just 0
    sts TCCR1A, temp
    ; force pin LOW to prevent DC current from damaging the buzzer ?
    cbi BZ_P, BZ_I
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
    push r17
    push r18
    push r19
    push ZL
    push ZH

    sts Current_BPM, r17 ; store current BPM in SRAM for reference

    ; substract 60 to get the BPM table idx (0 to 140), because we used BPMs b/w 60 and 200
    subi r17, 60

    ; mltiply idx by 2 (because .dw uses 2 bytes)
    mov r18, r17 ; MOVe lut index to r18 (keep r17 intact)
    clr r19 ; CLeaR r19 for the high byte of the offset
    lsl r18 ; Logical Shift Left (mult r18 by 2) (MSB goes in the Carry Flag (C))
    rol r19 ; ROtate Left thrpugh carry r19, here just pulls the shifted MSB from r18 in the Carry Flag

    ; set z pointer to table origin
    ldi ZL, low(BPM_Table * 2)
    ldi ZH, high(BPM_Table * 2)

    ; add the offset to the z pointer
    add ZL, r18
    adc ZH, r19

    ; get 16-bit delay value
    lpm r18, Z+ ; read low byte
    lpm r19, Z  ; read high byte

    ; safely update the SRAM metronome varq
    ; (to prevent the ISR from reading half a new value while writing it, temporarily disable interrupts)
    cli
    sts Tempo_Delay, r18
    sts Tempo_Delay+1, r19
    sei ; reenable interrupts

	; BPM is in r17
	rcall Draw_BPM

    ; restore
    pop ZH
    pop ZL
    pop r19
    pop r18
    pop r17
    ret
; ===#===

; === Setup sequence, runs once on startup ===
setup:
	; initialize stack pointer (just to be sure)
    ldi temp, high(RAMEND)
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp

    clr temp;
    sts Is_Playing, temp ; paused by default (on startup)


    /*; ~~ old code: ~~
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
    ; ^^^ old code ^^^*/

	; ---- Display Hardware Setup ----
    ldi temp, (1<<DISPLAY_DATA) | (1<<4) | (1<<DISPLAY_CLK)
    out DISPLAY_D, temp
    out DISPLAY_PORT, temp
    ; ---- Timer 0 (for display) ----
    ; Normal mode, Prescaler = 64 (16MHz / 64 = 250kHz. Overflow at 256 = ~976Hz)
    ldi temp, (1<<CS01) | (1<<CS00)
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
    ; !~~~~~~~~~~
    ; FIXME:
    ; ! temporary for testing, set TIMSK2 to 0 to disable buzzer for now
    ldi temp, 0
    sts TIMSK2, temp
    ; !~~~~~~~~~~
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

	rcall Inputs_Init ;


    ; -- init sequence in SRAM
    rcall Init_Sequence ; clear sequence

    ; -- init step
    clr temp ; default step 0
    sts Step, temp ; store default step in SRAM

    ; -- init bpm
    ldi r17, 120 ; default BPM
    rcall Update_BPM ; set default BPM from r17

	; ---- outputs ----
	; -- screen
	rcall Init_Display

	; ;buzzer output
    ; sbi BZ_OUT_DIR,BZ_OUT_IDX ;set buzzer out pin dir to output(1)
    ; cbi BZ_OUT_BANK,BZ_OUT_IDX ;clear buzzer to off

    ; -- leds output
    sbi LED2_D,LED2_I ;set led2 out pin dir to output(1)
    cbi LED2_P,LED2_I ;clear led2 to off
    sbi LED3_D,LED3_I ;set led3 out pin dir to output(1)
    cbi LED3_P,LED3_I ;clear led3 to off
	; ----#----

	sei ; enable interrupts (Set global Interrupt fags)
    rjmp loop
; ===#===

; === Clear Sequence (stratup) ===
Init_Sequence:
    push ZL
    push ZH
    push r17
    push temp

    ; z pointer to base address of the sequence in SRAM
    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)
    ; load rest/mute value
    ;ldi temp, 0xFF ; 0xFF means mute
	; FIXME: DEBUG
    ldi temp, 33 ; NOTE_A3 is idx 33, A (3rd octave) FIXME: for testing
    ; set below loop duration to the 32 steps
    ldi r17, 32
Fill_Sequence:
    ; store rest/mute value in sequence and auto-increment z pointer to next byte in SRAM
    st Z+, temp
    ; decr counter and loop if not zero
    dec r17
    brne Fill_Sequence
    ; Sequence is initialized with all mutes/rests

    pop temp
    pop r17
    pop ZH
    pop ZL
    ret
; ===#===

; === infinite loop (right after setup) ===
loop:

    rjmp User_Inputs ; handle user inputs (joystick, keypad) ; ? rjmp or rcall ?

    rjmp loop
; ===#===

; === Metronome's ISR ===
ISR_Metronome: ; called every time timer 2 reaches OCR2A (every (1ms or) 0.1ms)
    push r16 ; aka temp
    push r17
    push ZL
    push ZH
    in temp, SREG
    push temp

    ; -- incr 16-bit Tick Counter
    lds r16, Tick_Counter
    lds r17, Tick_Counter+1
    subi r16, low(-1) ; add 1 to low byte
    sbci r17, high(-1) ; add carry (from low byte) to high byte
    sts Tick_Counter, r16
    sts Tick_Counter+1, r17

    ; -- compare with Tempo_Delay (e.g. 1249 is 120 BPM)
    lds ZL, Tempo_Delay
    lds ZH, Tempo_Delay+1
    cp r16, ZL
    cpc r17, ZH
    brne End_ISR_Metronome ; if delay not reached: exit

    ; -- delay reached: reset Tick Counter to 0
    clr temp ; aka ldi temp,0
    sts Tick_Counter, temp
    sts Tick_Counter+1, temp

    ; -- skip playing the note if paused
    ; yeah keep running the Metronome even during pause to keep the timing, just skip the note-playing part
    lds temp, Is_Playing
    sbrs temp, 0 ; Skip if Bit in Register Set (first bit is 0 if paused, 1 if playing)
    rjmp End_Sequence_Play_Note ; still want to advance step even if paused

    ; -- play note for current step
    lds r17, Step ; get current step index
    ldi ZL, low(Sequence)
    ldi ZH, high(Sequence)
    clr temp ; clear temp for high byte addition
    add ZL, r17 ; add step index to z pointer to point to current step's note in sequence
    adc ZH, temp ; add carry to high byte (ZH) from low byte addition
    ld r17, Z ; load current step's note index into r17
    rcall Play_Note ; play the note for the current step (r17 is input idx)

    End_Sequence_Play_Note: ; still want to advance step even if paused

    ; -- advance sequencer step
    rcall Next_Step

    End_ISR_Metronome:
    ; -- restore stack
    pop temp
    out SREG, temp
    pop ZH
    pop ZL
    pop r17
    pop r16
    reti
; ===#===

Next_Step:
    ; advance sequencer step
    lds temp, Step
    ; check if at end of sequence (32 steps), loop back to 0
    cpi temp, 31
    brsh loop_to_start
    inc temp ; next step
    sts Step, temp
    rjmp End_Next_Step
    loop_to_start:
    clr temp ; aka ldi temp,0
    sts Step, temp
    End_Next_Step:
    ret

Prev_Step:
    ; move to previous step
    lds temp, Step
    ; check if at start of sequence (step 0), loop back to end (31)
    cpi temp, 1
    brlo loop_to_end
    dec temp ; previous step
    sts Step, temp
    rjmp End_Prev_Step
    loop_to_end:
    ldi temp, 31
    sts Step, temp
    End_Prev_Step:
    ret

; === outputs ===
LED2_ON:
    ; LOW enable
    cbi LED2_P,LED2_I ;set bit of led to high
    ret
LED2_OFF:
    sbi LED2_P,LED2_I ;set bit of led to low
    ret
LED3_ON:
    ; LOW enable
    cbi LED3_P,LED3_I ;set bit of led to high
    ret
LED3_OFF:
    sbi LED3_P,LED3_I ;set bit of led to low
    ret
;BUZON:
;    ldi R16, 0b1
;    sts TIMSK0,R16 ; enable timer 0 overflow interrupt
;    ret
;BUZOFF:
;    ldi R16, 0b0
;    sts TIMSK0,R16 ; disable timer 0 overflow interrupt
;    ret
; ===#===

