; SPDX-License-Identifier: GPL-3.0-or-later

; i2c-tiny-sniffer
; Simple I2C bus sniffer
; 
; Author : Sergey V. DUDANOV
; E-Mail : sergey.dudanov@gmail.com
; Git    : https://github.com/dudanov/i2c-tiny-sniffer
; License: GPL v3 (https://www.gnu.org/licenses/gpl.txt)
; 
; MCU:   ATTINY2313A @8MHz
; LFUSE: RC:0xE4 | QZ:0xFD
; HFUSE: 0xCF (WDTEN)
; EFUSE: 0xFF
; 
; I2C data => ASCII => USART
; USART: 1Mbps 7N1
; Start: '#'
; Stop:  '!'
; (N)ACK is ignored
; 
; Pins used:
; PB5: I2C SDA
; PB7: I2C SCL
; PD1: USART TX

; # GLOBAL REGISTERS
.def tmp            = r16   ; temporary register
.def st_val         = r17   ; const 0xE0
.def nb_val         = r18   ; const 0x6E
.def ack_val        = r19   ; const 0x60
.def sp_val         = r20   ; const 0xE0
.def st_sym         = r21   ; const '#'
.def sp_sym         = r22   ; const '!'

    ; ### SETUP BLOCK ###
    ; shutting down TIM0 and TIM1
    ldi   tmp, 0b1100           ; [1]
    out   PRR, tmp              ; [1]
    ; pull-up unused pins
    ldi   tmp, 0b111            ; [1]
    out   PORTA, tmp            ; [1]
    ldi   tmp, 0b1111111        ; [1]
    out   PORTD, tmp            ; [1]
    ; set global registers
    ldi   st_val, 0xE0          ; [1]
    ldi   nb_val, 0x6E          ; [1]
    ldi   ack_val, 0x60         ; [1]
    ldi   sp_val, 0x20          ; [1]
    ldi   st_sym, '#'           ; [1]
    ldi   sp_sym, '!'           ; [1]
    ldi   XL, 0x60              ; [1]
    ldi   XH, 0x00              ; [1]
    ldi   YL, 0x60              ; [1]
    ldi   YH, 0x00              ; [1]
    ldi   ZH, 0x01              ; [1]
    ; setup USART to TX mode: 7N1 @1Mbps
    ldi   tmp, (1 << U2X)       ; [1]
    out   UCSRA, tmp            ; [1]
    ldi   tmp, (1 << TXEN)      ; [1]
    out   UCSRB, tmp            ; [1]
    ldi   tmp, (0b10 << UCSZ0)  ; [1]
    out   UCSRC, tmp            ; [1]
    ; setup USI to I2C mode: SCL stretch on START and OVF
    ldi   tmp, 0b00111100       ; [1]
    out   USICR, tmp            ; [1]
    ; setup PORTB (unused, SDA and SCL pins)
    ldi   tmp, 0b11011111       ; [1]
    out   PORTB, tmp            ; [1]
    sbi   DDRB, DDB7            ; [2]

loop:
    ; ### MAIN PROGRAM LOOP ###
    wdr                         ; [1] reset watchdog timer
    ; ### USI START CONDITION BLOCK ###
    sbis  USISR, USISIF         ; [2][1]
    rjmp  PC+5                  ; [0][2] -> skip block
    ; start condition detected. waiting for pull-down SCL by master
    sbic  PINB, PINB7           ; [2][1] <-
    rjmp  PC-1                  ; [0][2] ->
    ; SCL is pull-down
    out   USISR, st_val         ; [1] reset all flags and counter. release SCL
    st    X+, st_sym            ; [2] put start symbol to queue
    
    ; ### USI COUNTER OVERFLOW BLOCK ###
    sbis  USISR, USIOIF         ; [2][1]
    rjmp  PC+11                 ; [0][2] -> skip block
    ; counter is overflowed. new byte received
    out   USISR, nb_val         ; [1] reset flags. set counter to 14. release SCL
    ; take byte from USI buffer register
    in    ZL, 0x00              ; [1] USIBR
    ; fast convert to ASCII and put to USART TX queue
    lpm   tmp, Z                ; [3]
    st    X+, tmp               ; [2]
    swap  ZL                    ; [1]
    lpm   tmp, Z                ; [3]
    st    X+, tmp               ; [2]
    ; waiting for (N)ACK (just two SCL edges)
    sbis  USISR, USIOIF         ; [2][1] <-
    rjmp  PC-1                  ; [0][2] ->
    ; (N)ACK received. ignoring it
    out   USISR, ack_val        ; [1] reset flags and counter. release SCL

    ; ### USI STOP CONDITION BLOCK ###
    sbis  USISR, USIPF          ; [2][1]
    rjmp  PC+3                  ; [0][2] -> skip block
    ; stop condition detected
    out   USISR, sp_val         ; [1] reset stop flag
    st    X+, sp_sym            ; [2] put stop symbol to USART TX queue

    ; ### USART TX BLOCK ###
    cpse  XL, YL                ; [1][1][2]
    sbis  UCSRA, UDRE           ; [2][1][0]
    rjmp  loop                  ; [0][2][2] -> queue empty or tx is busy
    ld    tmp, Y+               ; [2]
    out   UDR, tmp              ; [1] start tx. 64 clks before next UDRE
    cp    XL, YL                ; [1]
    brne  loop                  ; [1][2] -> data in queue is available
    ; reset queue pointers to start address of SRAM
    ldi   XL, 0x60              ; [1]
    ldi   YL, 0x60              ; [1]
    rjmp  loop                  ; [2] -> queue is reset

.org 0x80

.db '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0'
.db '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1'
.db '2','2','2','2','2','2','2','2','2','2','2','2','2','2','2','2'
.db '3','3','3','3','3','3','3','3','3','3','3','3','3','3','3','3'
.db '4','4','4','4','4','4','4','4','4','4','4','4','4','4','4','4'
.db '5','5','5','5','5','5','5','5','5','5','5','5','5','5','5','5'
.db '6','6','6','6','6','6','6','6','6','6','6','6','6','6','6','6'
.db '7','7','7','7','7','7','7','7','7','7','7','7','7','7','7','7'
.db '8','8','8','8','8','8','8','8','8','8','8','8','8','8','8','8'
.db '9','9','9','9','9','9','9','9','9','9','9','9','9','9','9','9'
.db 'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A'
.db 'B','B','B','B','B','B','B','B','B','B','B','B','B','B','B','B'
.db 'C','C','C','C','C','C','C','C','C','C','C','C','C','C','C','C'
.db 'D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D'
.db 'E','E','E','E','E','E','E','E','E','E','E','E','E','E','E','E'
.db 'F','F','F','F','F','F','F','F','F','F','F','F','F','F','F','F'
