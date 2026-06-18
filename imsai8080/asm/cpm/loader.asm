	.cpu 8080
; =============================================================================
; VERSAFLOPPY II I/O PORTS (for IMSAI8080 calypso core)
; =============================================================================
VF_BASE     EQU 060H            ; Base address for Versafloppy II
FDC_CMD     EQU VF_BASE + 4     ; WD1793 Command (W) / Status (R)
FDC_TRK     EQU VF_BASE + 5     ; WD1793 Track Register
FDC_SEC     EQU VF_BASE + 6     ; WD1793 Sector Register
FDC_DAT     EQU VF_BASE + 7     ; WD1793 Data Register

VF_CTRL     EQU VF_BASE + 3     ; Control Port (Drive/Side select)


; =============================================================================
; CP/M MEMORY DESTINATIONS (Standard 64K CP/M configuration example)
; =============================================================================
CCP_DEST    EQU 0DC00H          ; Destination address for CCP + BDOS
CCP_SECTS   EQU 44              ; 44 sectors * 128 bytes = 5632 bytes

BIOS_DEST   EQU 0FA00H          ; Destination address for BIOS
BIOS_SECTS  EQU 4               ; 4 sectors * 128 bytes = 512 bytes

; =============================================================================
; WD1793 COMMANDS
; =============================================================================
CMD_RESTORE EQU 00CH            ; Seek to Track 0
CMD_READ_S  EQU 08CH            ; Read Single Sector
CMD_STEP_IN EQU 058H            ; Step-In without updating track register

	ORG 0800H               ; MEMON80 boot destination address 

RESET:      LXI SP, 0100H       ; Initialize temporary stack pointer

            ; 1. Configure Versafloppy II Control Port
            ; Select Drive A, Side 0, Minidisc, Single Density (FM)
            MVI A, 10100001B    ; Drive A    00000001
                                ; Side  0    000_0000
                                ; Minidisk   00100000
                                ; Autowait   10000000
            OUT VF_CTRL

            ; 2. Restore Head to Track 0
            MVI A, CMD_RESTORE
            OUT FDC_CMD
            CALL WAIT_FDC       ; Wait until command completes

            ; 3. Initialize tracking variables
            MVI C, 0            ; C = Current Track (0)
            MVI E, 2            ; E = Current Sector (2). This loader in sector 1

            ; 4. Read the CCP + BDOS block
            LXI H, CCP_DEST    ; HL = Destination pointer
            MVI B, CCP_SECTS    ; B = Sectors to read
            CALL READ_BLOCK

            ; 5. Read the BIOS block
            LXI H, BIOS_DEST   ; HL = Destination pointer
            MVI B, BIOS_SECTS   ; B = Sectors to read
            CALL READ_BLOCK

            ; Disable autowait and drive 0 selection
            MVI A, 00100000B
            OUT VF_CTRL

            ; 6. Execution handoff
            JMP BIOS_DEST       ; Boot straight into the BIOS Cold Boot vector

; =============================================================================
; BLOCK READ SUBROUTINE
; Inputs:  HL = Destination Address
;          B  = Sector Count
;          C  = Current Track
;          E  = Current Sector
; =============================================================================
READ_BLOCK:
BLOOP:      PUSH B              ; Save remaining sector count & track
            PUSH D              ; Save current sector tracking

            ; Program WD1793 Registers
            MOV A, C
            OUT FDC_TRK         ; Load track
            MOV A, E
            OUT FDC_SEC         ; Load sector

            ; Issue Read Sector Command
            MVI A, CMD_READ_S
            OUT FDC_CMD

            ; -----------------------------------------------------------------
            ; HARDWARE-ASSISTED DATA TRANSFER LOOP
            ; Versafloppy II holds the 8080 in a WAIT state on every 'IN FDC_DAT'
            ; instruction until a disk byte is physically ready.
            ; -----------------------------------------------------------------
            MVI D, 128          ; 128 bytes per sector
XFER_LOOP:  IN FDC_DAT          ; CPU halts here until data byte is ready
            MOV M, A            ; Store byte to memory destination
            INX H               ; Point to next memory address
            DCR D               ; Decrement loop counter
            JNZ XFER_LOOP       ; Repeat for all 128 bytes

            ; Wait for the WD1793 to completely clear its internal BUSY state
            CALL WAIT_FDC

            ; Pop variables back to check for errors and calculate positioning
            POP D
            POP B

            ; Check disk controller status for transmission or seek errors
            IN FDC_CMD
            ANI 01CH            ; Mask Error Flags (CRC, Record Not Found, Lost Data)
            JNZ FDC_ERROR       ; Lock up system if sector read failed

            ; Calculate next logical location
            INR E               ; Increment Sector count
            MOV A, E
            CPI 27              ; Past sector 26?
            JC NEXT_SEC         ; If sector <= 26, keep tracking on this track

            ; Sector Overflow: Cross track boundary
            MVI E, 1            ; Reset sector counter back to 1
            INR C               ; Increment target Track number

            ; Tell physical drive head to move in one track step
            MVI A, CMD_STEP_IN
            OUT FDC_CMD
            CALL WAIT_FDC       ; Wait for head stepping to finish

NEXT_SEC:   DCR B               ; Decrement block sector counter
            JNZ BLOOP           ; If sectors remain, fetch the next one
            RET

; =============================================================================
; WAIT FOR FDC COMPLETION
; Polls the WD1793 status register until the BUSY bit (Bit 0) drops low.
; =============================================================================
WAIT_FDC:   IN FDC_CMD
            ANI 01H             ; Check Bit 0 (BUSY)
            JNZ WAIT_FDC        ; If 1, keep polling
            RET

; =============================================================================
; CRITICAL ERROR HANDLER
; Hhalts execution safely if a bad sector read or tracking failure occurs.
; =============================================================================
FDC_ERROR:  DI                  ; Disable interrupts
            HLT                 ; Halt the 8080 system
