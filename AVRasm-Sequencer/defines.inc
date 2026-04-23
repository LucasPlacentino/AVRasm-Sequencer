;
; display.inc :
; PROJECT for Sensors and Microsystem Electronics, final file version
; Date : 2026
; Author : Lucas Placentino
; License: MIT
;

; this file is just for some .equ and preset data in flash mem

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

; === Notes LUT ===
; to play a sound, load the note index into a reg (r17), then using a LUT to get the correct value to put in ocr1a ? rather than too many branches
; store this LUT in the flash mem:
; 48 notes (idx 0 to 47)
Note_Table:
; .dw is define word(s)
    ; -- octave 1 (idx 0 to 11)
    .dw NOTE_C1, NOTE_CS1, NOTE_D1, NOTE_DS1
    .dw NOTE_E1, NOTE_F1, NOTE_FS1, NOTE_G1
    .dw NOTE_GS1, NOTE_A1, NOTE_AS1, NOTE_B1
    ; -- octave 2 (ixd 12 to 23)
    .dw NOTE_C2, NOTE_CS2, NOTE_D2, NOTE_DS2
    .dw NOTE_E2, NOTE_F2, NOTE_FS2, NOTE_G2
    .dw NOTE_GS2, NOTE_A2, NOTE_AS2, NOTE_B2
    ; -- octave 3 (idx 24 to 35)
    .dw NOTE_C3, NOTE_CS3, NOTE_D3, NOTE_DS3
    .dw NOTE_E3, NOTE_F3, NOTE_FS3, NOTE_G3
    .dw NOTE_GS3, NOTE_A3, NOTE_AS3, NOTE_B3
    ; -- octave 4 (idx 36 to 47)
    .dw NOTE_C4, NOTE_CS4, NOTE_D4, NOTE_DS4
    .dw NOTE_E4, NOTE_F4, NOTE_FS4, NOTE_G4
    .dw NOTE_GS4, NOTE_A4, NOTE_AS4, NOTE_B4
;    ; -- octave 5 (idx 48)
;    .dw NOTE_C5 ; let's only use 4 octaves it's good enough
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
; ; hmh not precise enough, too rounded
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

.equ MAX_BPM = 200
.equ MIN_BPM = 60

; === Default Startup Melody Data ===
; 0xFF is blank note (mute)
; NOTE: these were generated using an LLM !
;       (i'm no musician and dont know music theory)

; Ode to Joy (Octave 4), 32 steps
; Preset_Melody_1:
;     ; Measure 1: E, E, F, G
;     .db 40, 0xFF, 40, 0xFF, 41, 0xFF, 43, 0xFF
;     ; Measure 2: G, F, E, D
;     .db 43, 0xFF, 41, 0xFF, 40, 0xFF, 38, 0xFF
;     ; Measure 3: C, C, D, E
;     .db 36, 0xFF, 36, 0xFF, 38, 0xFF, 40, 0xFF
;     ; Measure 4: E (dotted), D (eighth), D (half)
;     .db 40, 0xFF, 0xFF, 38, 38, 0xFF, 0xFF, 0xFF

; Super Mario Bros - Overworld Theme (32 steps)
; Preset_Melody_2:
;     ; Measure 1: E4, E4, (rest), E4, (rest), C4, E4, (rest)
;     .db 40, 40, 0xFF, 40, 0xFF, 36, 40, 0xFF
;     ; Measure 2: G4, (restx3), G3, (restx3)
;     .db 43, 0xFF, 0xFF, 0xFF, 31, 0xFF, 0xFF, 0xFF
;     ; Measure 3: C4, (restx2), G3, (restx2), E3, (rest)
;     .db 36, 0xFF, 0xFF, 31, 0xFF, 0xFF, 28, 0xFF
;     ; Measure 4: (rest), A3, (rest), B3, (rest), Bb3, A3, (rest)
;     .db 0xFF, 33, 0xFF, 35, 0xFF, 34, 33, 0xFF

; Tetris Theme (Korobeiniki) - 32 steps (Lower Octave)
; Preset_Melody_3:
;     ; Measure 1: E4 (quarter), B3 (8th), C4 (8th), D4 (quarter), C4 (8th), B3 (8th)
;     .db 40, 0xFF, 35, 36, 38, 0xFF, 36, 35
;     ; Measure 2: A3 (quarter), A3 (8th), C4 (8th), E4 (quarter), D4 (8th), C4 (8th)
;     .db 33, 0xFF, 33, 36, 40, 0xFF, 38, 36
;     ; Measure 3: B3 (dotted-quarter), C4 (8th), D4 (quarter), E4 (quarter)
;     .db 35, 0xFF, 35, 36, 38, 0xFF, 40, 0xFF
;     ; Measure 4: C4 (quarter), A3 (quarter), A3 (quarter), (rest)
;     .db 36, 0xFF, 33, 0xFF, 33, 0xFF, 0xFF, 0xFF

;; ; Star Wars - Main Theme (32 steps) ; doesn't sound good
;; Default_Melody_no:
;;     ; Measure 1: C3 (Half), G3 (Half)
;;     .db 24, 24, 24, 0xFF, 31, 31, 31, 31
;;     ; Measure 2: F3, E3, D3 (Triplet-ish), C4 (Half)
;;     .db 30, 28, 26, 0xFF, 36, 36, 36, 36
;;     ; Measure 3: G3 (Half), F3, E3, D3 (Triplet-ish)
;;     .db 31, 31, 31, 31, 30, 28, 26, 0xFF
;;     ; Measure 4: C4 (Half), G3 (Half)
;;     .db 36, 36, 36, 0xFF, 31, 31, 31, 31

;; ; no
;; Default_Melody:
;;     ; Steps 1-8: E3, E3, blank, E3, E3, A3, B3, C4
;;     .db 28, 28, 28, 0xFF, 28, 33, 35, 36
;;     ; Steps 9-16: C4, C4, C4, blank, blank, blank, C4, C4
;;     .db 36, 36, 36, 36, 0xFF, 0xFF, 36, 36
;;     ; Steps 17-24: blank, C4, C4, C4, C4, B3, A3, blank
;;     .db 0xFF, 36, 36, 36, 36, 36, 36, 35
;;     ; Steps 25-32: F3, F3, F3, F3, F3, blank, blank, blank
;;     .db 33, 30, 30, 30, 30, 30, 30, 0xFF

; Imperial March (Darth Vader's Theme) - 32 steps
; Preset_Melody_4:
;     ; Measure 1: G3, G3, G3, Eb3 (8th), Bb3 (16th)
;     .db 31, 0xFF, 31, 0xFF, 31, 0xFF, 27, 34
;     ; Measure 2: G3 (quarter), Eb3 (8th), Bb3 (16th), G3 (half)
;     .db 31, 0xFF, 27, 34, 31, 0xFF, 0xFF, 0xFF
;     ; Measure 3: D4, D4, D4, Eb4 (8th), Bb3 (16th)
;     .db 38, 0xFF, 38, 0xFF, 38, 0xFF, 39, 34
;     ; Measure 4: Gb3 (quarter), Eb3 (8th), Bb3 (16th), G3 (half)
;     .db 30, 0xFF, 27, 34, 31, 0xFF, 0xFF, 0xFF

; Seven Nation Army - The White Stripes (32 steps), sounds best around 70bpm
Default_Melody:
    ; --- FIRST LOOP ---
    ; Measure 1: E4 (dotted quarter), E4 (8th), G4 (8th), E4 (8th), D4 (8th)
    .db 40, 40, 40, 0xFF, 40, 43, 40, 38
    ; Measure 2: C4 (half), B3 (half)
    .db 36, 36, 36, 0xFF, 35, 35, 35, 0xFF
    ; --- SECOND LOOP ---
    ; Measure 3: E4 (dotted quarter), E4 (8th), G4 (8th), E4 (8th), D4 (8th)
    .db 40, 40, 40, 0xFF, 40, 43, 40, 38
    ; Measure 4: C4 (half), B3 (half)
    .db 36, 36, 36, 0xFF, 35, 35, 35, 0xFF

; ===#===
