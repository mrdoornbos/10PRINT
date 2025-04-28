; 10PRINT for KIM-1 using scrolling display technique
; by Michael Doornbos <mike@imapenguin.com> 2025 

; This program generates a random pattern of slashes and backslashes
; and displays it on the KIM-1's 7-segment display.

; The pattern scrolls to the left, creating a continuous effect.


; Constants for 7-segment display characters
backslash  .equ $64        ; Backslash character
slash      .equ $52        ; Forward slash character
spc        .equ $80        ; Space character

; KIM-1 hardware addresses
SAD     .equ $1740      ; data port for pins 1-4
SADD    .equ $1741      ; data direction register A
SBD     .equ $1742      ; data port for pins 5-6
SBDD    .equ $1743      ; data direction register B
TIMER2  .equ $1747      ; optional 2nd 6532 timer
lout    .equ $7f        ; set pins as output to left 4 LEDs
rout    .equ $1e        ; set pins as output to right 2 LEDs

; Zero page variables
SEED    .equ $00D0      ; Random seed location
tmr     .equ $00DB      ; Timer counter
ptr     .equ $00DC      ; Pointer
xfrhi   .equ $00DD      ; Used for character buffer high byte
xfrlo   .equ $00DE      ; Used for character buffer low byte
tmp1    .equ $00DF      ; Temporary storage
cbuff   .equ $00E8      ; Character buffer (6 bytes)
MSGBUF  .equ $0180      ; Buffer for generated patterns (30 bytes)

        .org $0200      ; Start of program code

main    
        ; Clear the message buffer first to prevent glitches
        LDX #$00
clrloop LDA #spc        ; Use space character to initialize
        STA MSGBUF,X
        INX
        CPX #$30        ; Clear the entire buffer area
        BNE clrloop
        
        LDA #$00        ; Add null terminator at the end
        STA MSGBUF+23
        
        LDA #$42        ; Initialize random seed
        STA SEED        ; with non-zero value
        
        JSR GENPAT      ; Generate initial pattern
        
infinit LDY #>MSGBUF    ; Load buffer location
        LDA #<MSGBUF
        JSR scan        ; Display the pattern
        
        ; Generate new random slash at end of buffer
        JSR RANDOM      ; Get random bit
        BCC genback     ; Branch if carry clear (50% chance)
        
        LDA #slash      ; Forward slash
        JMP store
        
genback LDA #backslash  ; Backslash
        
store   STA MSGBUF+22   ; Add new character to end of buffer
        
        ; Shift buffer left one position (scroll effect)
        LDX #$00        ; Start at first position
shift   LDA MSGBUF+1,X  ; Get next character
        STA MSGBUF,X    ; Store in current position
        INX             ; Move to next position
        CPX #$22        ; Check if we're at end of buffer
        BNE shift       ; Continue if not at end
        
        ; Ensure null terminator is always present
        LDA #$00
        STA MSGBUF+23
        
        JMP infinit     ; Loop forever

; Generate initial pattern buffer with random slashes
GENPAT  LDX #$00        ; Start at first position
gploop  JSR RANDOM      ; Get random bit
        BCC gback       ; Branch if carry clear
        
        LDA #slash      ; Forward slash
        JMP gstore
        
gback   LDA #backslash  ; Backslash
        
gstore  STA MSGBUF,X    ; Store in buffer
        INX             ; Next position
        CPX #$17        ; Check if buffer is full
        BNE gploop      ; Continue if not full
        
        LDA #$00        ; Add null terminator
        STA MSGBUF+23   ; at end of buffer
        RTS             ; Return

; Random number generator (8-bit LFSR)
RANDOM  LDA SEED        ; Load current seed
        ASL             ; Shift left (C gets high bit)
        BCC NOEOR       ; Skip EOR if bit 7 was 0
        EOR #$B4        ; Apply feedback polynomial
NOEOR   STA SEED        ; Store updated seed
        RTS             ; Return with carry = random bit

; Scanning routine from original code
scan    STY xfrlo       ; y and a get loaded before jsr to scan
        STA xfrhi
        LDA #$07        ; init scan forward
        STA tmp1
        LDY #$05        ; init y
cont    LDX #$05        ; init x
char    LDA (xfrhi),Y   ; get character
        CMP #$00        ; last character?
        BNE more        ; if not, continue
        RTS
more    STA cbuff,X     ; store char
        DEY             ; set up next char
        DEX             ; set up next store loc
        BPL char        ; loop if not 6th char
        CLD             ; binary mode
        CLC             ; prepare to add (clear carry flag)
        TYA             ; get char pointer
        ADC tmp1        ; update for 6 new characters
        STA ptr         ; save new pointer
        JSR dspdly      ; delay display
        LDY ptr         ; restore pointer
        JMP cont        ; continue with rest of message

dspdly  LDX #$0A        ; set the delay rate here
        STX tmr         ; put in decr. location
time    LDA #$52        ; load timer
        STA TIMER2      ; start timer
lite    JSR disp        ; gosub display rtn
        BIT TIMER2      ; timer done?
        BPL lite        ; if not, loop
        DEC tmr         ; decrement timer counter
        BNE time        ; not finished
        RTS             ; now get 6 new characters

disp    LDA #lout       ; change left led segments
        STA SADD        ; to outputs
        LDY #$00        ; init recall index
        LDX #$09        ; init digit number
six     LDA cbuff,Y     ; get character
        STY $00FC       ; save y for monitor disp routine
        JSR $1F4E       ; monitor routine - disp char, delay 500 cycles
        INY             ; set up for next char
        CPY #$06        ; 6 char displayed?
        BCC six         ; no
        RTS
