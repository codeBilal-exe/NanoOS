[org 0x7C00]
[bits 16]

; BIOS passes boot drive in DL, save it
mov [BOOT_DRIVE], dl

; Setup stack securely
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov bp, 0x8000
mov sp, bp

; Print the NanoOS ASCII Logo
mov bx, MSG_LOGO
call print_string


; Delay for 1.5 seconds so the user can see the boot screen!
; INT 15h, AH=86h waits for CX:DX microseconds
; 1,500,000 us = 0x0016E360
mov ah, 0x86
mov cx, 0x0016
mov dx, 0xE360
int 0x15

; Load Kernel from disk
mov ah, 0x02        ; BIOS read sector function
mov al, 16          ; Read 16 sectors
mov ch, 0           ; Cylinder 0
mov dh, 0           ; Head 0
mov cl, 2           ; Sector 2 (Sector 1 is our bootloader)
mov dl, [BOOT_DRIVE]; Read from the boot drive
mov bx, 0x8000      ; Load to address 0x8000
int 0x13

jc disk_error       ; If carry flag is set, there was a disk error

; Save boot drive for kernel to use
mov byte [0x7E00], dl

; Jump to Kernel
jmp 0x8000

disk_error:
    mov bx, MSG_DISK_ERROR
    call print_string
    jmp $           ; Hang forever

; Function: print_string
; Parameters: BX = address of null-terminated string
print_string:
    pusha
    mov ah, 0x0e    ; TTY output mode
.loop:
    mov al, [bx]
    cmp al, 0
    je .done
    int 0x10        ; Print character in AL
    inc bx
    jmp .loop
.done:
    popa
    ret

; Variables / Data
BOOT_DRIVE: db 0
MSG_DISK_ERROR: db 'Error loading kernel from disk!', 13, 10, 0

; Include the ASCII art logo
%include "boot/logo.asm"

; Boot sector magic number
times 510-($-$$) db 0
dw 0xAA55
