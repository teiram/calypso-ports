; =============================================================================
; CP/M 2.2 BIOS FOR SD SYSTEMS VERSAFLOPPY II
; CPU: INTEL 8080
; CONSOLE: IMSAI SIO-2 SERIAL PORT A
; PRINTER: IMSAI SIO-2 SERIAL PORT B
; DISK CONTROLLER: WESTERN DIGITAL FD1791/1793 (VERSAFLOPPY II)
; CHANGELOG
; =============================================================================
; VERSION 0.1. Initial Version
; VerSION 0.2. Printer on serial port B
; =============================================================================
        .cpu 8080
CCP     EQU     0DC00H   ; Base of CP/M Console Command Processor
BDOS    EQU     0E406H   ; Base of Basic Disk Operating System
BIOS    EQU     0FA00H   ; Base of this BIOS
; -----------------------------------------------------------------------------
; IMSAI SIO-2 SERIAL PORT DEFINITIONS 
; -----------------------------------------------------------------------------
SIO1CNT EQU     03H             ; SIO-2 Port A Control/Status Port
SIO1DAT EQU     02H             ; SIO-2 Port A Data Port
SIO2CNT EQU     05H             ; SIO-2 Port B Control/Status Port
SIO2DAT EQU     04H             ; SIO-2 Port B Data Port

SIORDY  EQU     02H             ; Bit 1: RTS (1 = Data available)
SIOTDY  EQU     01H             ; Bit 0: CTS (1 = Clear to send)

; -----------------------------------------------------------------------------
; VERSAFLOPPY II CONTROLLER I/O PORTS
; -----------------------------------------------------------------------------
VFBASE  EQU     60H
FCMD    EQU     VFBASE + 4        ; FD179X Command Register (Output)
FSTAT   EQU     VFBASE + 4        ; FD179X Status Register (Input)
FTRK    EQU     VFBASE + 5        ; FD179X Track Register (I/O)
FSEC    EQU     VFBASE + 6        ; FD179X Sector Register (I/O)
FDAT    EQU     VFBASE + 7        ; FD179X Data Register (I/O)
VCNTRL  EQU     VFBASE + 3        ; Drive/Side/Density Select Register (Output)

; Versafloppy II Control Register Bits (Port VFBASE+3)
; Bit 0-3: Drive Select (0=Drive A, 1=Drive B, etc.)
; Bit 4:   Side Select (0=Side 0, 1=Side 1)
; Bit 5:   Set up for minidisk
; Bit 6:   Density Select (0=Double Density / MFM, 1=Single Density / FM)
; Bit 7:   Enables Hardware Wait-State Generation on FDAT Access
MINID   EQU     00100000B       ; Minidisk bit
VWAIT   EQU     10000000B       ; Wait state bit

; =============================================================================
; CP/M JUMP VECTOR TABLE
; =============================================================================
        ORG     BIOS

        JMP     BOOT            ; 00: Cold Boot
WBOOTE: JMP     WBOOT           ; 01: Warm Boot
        JMP     CONST           ; 02: Console Status
        JMP     CONIN           ; 03: Console Input
        JMP     CONOUT          ; 04: Console Output
        JMP     LIST            ; 05: Printer Output
        JMP     PUNCH           ; 06: Paper Tape Punch Output
        JMP     READER          ; 07: Paper Tape Reader Input
        JMP     HOME            ; 08: Home Drive Head to Track 0
        JMP     SELDSK          ; 09: Select Disk Drive
        JMP     SETTRK          ; 10: Set Track Number
        JMP     SETSEC          ; 11: Set Sector Number
        JMP     SETDMA          ; 12: Set DMA Address
        JMP     READ            ; 13: Read Sector
        JMP     WRITE           ; 14: Write Sector
        JMP     LISTST          ; 15: Printer Status
        JMP     SECTRAN         ; 16: Sector Translation

; ===============================================================================
; CP/M DISK PARAMETER SCHEMES (Standard IBM 8" SSSD Format 26-Sectors, 77-Tracks)
; ===============================================================================
DPH0:   DW      0000H, 0000H
        DW      0000H, 0000H
        DW      DIRBUF, DPB8
        DW      CSV0, ALV0
DPH1:   DW      0000H, 0000H
        DW      0000H, 0000H
        DW      DIRBUF, DPB8
        DW      CSV1, ALV1

DPB8:   DW      26              ; Sectors per Track
        DB      3               ; Block Shift (for 1K blocks)
        DB      7               ; Block Mask  (for 1K blocks)
        DB      0               ; Extent Mask (for 1K blocks)
        DW      242             ; Disk capacity - 1 (in blocks, discounting system tracks: (3328 * (77 - 2) / 1024)) - 1
        DW      63              ; Directory max - 1 (64 directory entries)
        DB      11000000B       ; Directory allocation vectors: 64 * 32 bytes per entry = 2048 = 2 1K blocks
        DB      00000000B       ;                                                          11000000 00000000
        DW      16              ; Check directory size
        DW      2               ; Track offset (System reserved tracks)

; =============================================================================
; BANNER MESSAGE
; =============================================================================
BANNER: DB      'IMSAI8080 CP/M BIOS 0.2', 0dh, 0h
; =============================================================================
; SYSTEM INITIALIZATION (BOOT & WBOOT)
; =============================================================================
BOOT:   LXI     SP, 0100H       ; Initial stack (should be safe)
        XRA     A
        STA     CDISK           ; Default drive = A

        LXI     H, BANNER       ; Load banner address
BLOOP:  MOV     A, M            ; Character into A
        ORA     A
        JZ      GOCPM           ; If zero we are done with the banner, start CPM
        MOV     C, A
        CALL    CONOUT          ; Print char
        INX     H               ; Increment pointer
        JMP     BLOOP           ; Loop over
        
WBOOT:  
        LXI     SP, 0100H       ; Reset stack on warm boot

                                ; Reload CCP/BDOS from disk first tracks on warm boot
                                ; Starting on track 0 sector 2 (Sector 1 holds the initial
                                ; loader)
                                ;
        MVI     C, 0            ; Drive to boot from 
        CALL    SELDSK

        LXI     H, CCP          ; Write directly on CCP area
        MVI     B, 44           ; Sector count 
        MVI     C, 0            ; Start track
        MVI     D, 2            ; Start sector
        
LDCCP:  PUSH    B               ; Store sector counter and current track
        PUSH    D               ; Store current sector
        PUSH    H               ; Store current DMA
        
        MOV     A, C
        STA     VTRK            ; Set track to read from 
        MOV     A, D
        STA     VSEC            ; Set sector to read from
        SHLD    VDMA

        CALL    READ            ; Use BIOS routine to read sector

        POP     H               ; Restore destination address
        LXI     B, 0080H 
        DAD     B               ; Add 128 to it (sector size)
        
        POP     D               ; Restore current sector
        POP     B               ; Restore sector counter and current track

        DCR     B               ; Decrement sector counter
        JZ      GOCPM           ; If done, jump into CPM vectors setup

        INR     D               ; Increment sector number
        MOV     A, D
        CPI     27              ; Is it over 27? (26 sectors per track, from 1 to 27)
        JC      LDCCP           ; Keep loading

        MVI     D, 1            ; Reset sector to 1
        INR     C               ; Increment track
        JMP     LDCCP           ; Keep loading

GOCPM:  MVI     A, 0C3H         ; JUMP opcode
        STA     0000H           ; Set up CP/M reset entry point
        LXI     H, WBOOTE
        SHLD    0001H
        
        STA     0005H           ; Set up BDOS entry point vector
        LXI     H, BDOS
        SHLD    0006H

        LXI     B, 0080H
        CALL    SETDMA          ; DMA buffer to 0080H

        LDA     CDISK
        MOV     C, A            ; Pass active drive letter to CCP
        JMP     CCP             ; Execute the CP/M environment

; =============================================================================
; IMSAI SIO-2 SERIAL CHARACTER I/O ROUTINES
; =============================================================================
CONST:  IN      SIO1CNT         ; Read status register
        ANI     SIORDY          ; Is data waiting?
        RZ                      ; Return A=0 if not ready
        MVI     A, 0FFH         ; Character exists
        RET

CONIN:  IN      SIO1CNT         ; Poll port
        ANI     SIORDY
        JZ      CONIN           ; Wait loop
        IN      SIO1DAT         ; Fetch character from UART
        ANI     7FH             ; Mask parity bit
        RET

CONOUT: IN      SIO1CNT         ; Poll port
        ANI     SIOTDY          ; Is transmitter clearing down?
        JZ      CONOUT          ; Wait loop
        MOV     A, C            ; Get target character
        OUT     SIO1DAT         ; Output to SIO-2 terminal line
        RET

LIST:   IN     SIO2CNT          ; Check status
        ANI    SIOTDY           ; Clear to send?
        JZ     LIST             ; Wait if not ready
        MOV    A, C
        OUT    SIO2DAT          ; Senc char to SIO-2
        RET
PUNCH:  RET
READER: MVI     A, 1AH          ; Return EOF for paper tape
        RET
LISTST: IN    SIO2CNT           ; Check status
        ANI   SIOTDY            ; Clear to send?
        RZ 
        MVI     A, 0FFH         ; Port busy
        RET

; =============================================================================
; DISK ROUTINES
; =============================================================================
SELDSK: LXI     H, 0000H
        MOV     A, C
        CPI     2               ; Drive can be 0 or 1
        RNC                     ; Error if not
        CPI     1
        JZ      DRV1
        MVI     A, 01H
        JMP     DRV0
DRV1:   MVI     A, 02H   
DRV0:   STA     SELDV
        MOV     A, C
        ADD     A               ; Double (x2)
        ADD     A               ; Double (x4)
        ADD     A               ; Double (x8)
        ADD     A               ; Double (x16) - 16 bytes per DPH structure
        LXI     H, DPH0
        MOV     E, A
        MVI     D, 0
        DAD     D               ; HL point to selected DPH
        RET

HOME:   MVI     C, 0
        CALL    SETTRK          ; Set track to zero
        MVI     A, 08H          ; WD179X RESTORE command (step rate fast)
        OUT     FCMD
        CALL    WAITFDC         ; Hold thread execution until arm sets home
        RET

SETTRK: MOV     A, C
        STA     VTRK            ; Record requested track
        RET

SETSEC: MOV     A, C
        STA     VSEC            ; Record requested sector
        RET

SETDMA: MOV     H, B
        MOV     L, C
        SHLD    VDMA            ; Save location memory target address
        RET

SECTRAN:INX     B               ; Increment 1 for physical sector
        MOV     H, B
        MOV     L, C
        RET

READ:   CALL    SEEKHEAD        ; Move to the requested track (if needed)

        LDA     VSEC
        OUT     FSEC            ; Set sector to read
        
        CALL    VMODESEL        ; Get basic controller configuration in A
        ORI     VWAIT           ; Turn on wait state feature bit 
        OUT     VCNTRL          ; Configure controller

        MVI     A, 80H          ; WD179X Read Sector Command
        OUT     FCMD            ; Send command block

        LHLD    VDMA            ; Get pointer destination
        MVI     B, 128          ; Sector length
        
R_LOOP: IN      FDAT            ; CPU enters hardware wait-state until DRQ goes high
        MOV     M, A            ; Save to RAM (VDMA)
        INX     H               ; Increment RAM position
        DCR     B               ; Decrement counter loop
        JNZ     R_LOOP          ; Loop until the whole sector is read

        XRA     A
;        OUT     VCNTRL          ; Disengage hardware wait states completely
        RET                     ; TODO: Find out what codes to check exactly

        CALL    CHKSTATUS       ; Catch final status flags
        ANI     9CH             ; Filter CRC or seek error bits
        RZ                      ; If zero, read executed cleanly
        MVI     A, 1            ; Signal persistent sector read exception
        RET

WRITE:  CALL    SEEKHEAD        ; Move to the requested track (if needed)

        LDA     VSEC
        OUT     FSEC            ; Set sector to write

        CALL    VMODESEL        ; Get basic controller configuration in A
        ORI     VWAIT           ; Turn on wait state feature bit
        OUT     VCNTRL          ; Configure controller

        MVI     A, 0A0H         ; WD179X Write Sector Command
        OUT     FCMD

        LHLD    VDMA            ; Load into HL the buffer address
        MVI     B, 128          ; Bytes to write
        
W_LOOP: MOV     A, M            ; Load (HL) into A
        OUT     FDAT            ; CPU waits until DRQ goes high (Controller requesting byte)
        INX     H               ; Increment pointer
        DCR     B               ; Decrement byte count
        JNZ     W_LOOP          ; Loop until all written

        XRA     A
 ;       OUT     VCNTRL          ; Clear controller options and wait state lines
        CALL    CHKSTATUS
                                ; TODO: Check what bits to check exactly
        ANI     7CH             ; Check for write protect or data errors
        RZ                      ; Clean exit
        MVI     A, 1            ; Signal hardware write failure flag
        RET

; =============================================================================
; Disk helper routines
; =============================================================================
VMODESEL:
        LDA     SELDV           ; Get drive selection mask
        ANI     03H             ; Mask down safely (only drives 0 and 1 allowed)
        ORI     MINID           ; Set up for minidisc
        RET

SEEKHEAD:
        CALL    VMODESEL        ; Enable the proper drive
        OUT     VCNTRL          ; Configure controller
        

        
        LDA     VTRK
        MOV     C, A            ; Load requested track into C
        IN      FTRK            ; Get current track into A
        CMP     C
        RZ                      ; If we are on the right track, do nothing
        
        MOV     A, C
        OUT     FDAT            ; Write track to controller
        MVI     A, 18H          ; WD179X Seek command
        OUT     FCMD            ; Write command to controller
        
WAITFDC:IN      FSTAT           ; Poll the 179x Status Register
        RRC                     ; Shift BUSY flag out to Carry bit
        JC      WAITFDC         ; Loop if controller is still executing operation
        RET

CHKSTATUS:
        IN      FSTAT           ; Fetch completion flags 
        RET

; =============================================================================
; SYSTEM WORK RAM ASSIGNMENTS
; =============================================================================
CDISK:  DB      0               ; Current working drive (0, 1)
SELDV:  DB      0               ; Drive selection mask
VTRK:   DB      0               ; Current track
VSEC:   DB      0               ; Current sector
VDMA:   DW      0000H           ; DMA address for read and write commands

DIRBUF: DS      128             ; Shared allocation directory scratching block
CSV0:   DS      16              ; Drive A space monitoring arrays
CSV1:   DS      16              ; Drive B space monitoring arrays
ALV0:   DS      31              ; Allocation allocation storage drive maps
ALV1:   DS      31

        END
