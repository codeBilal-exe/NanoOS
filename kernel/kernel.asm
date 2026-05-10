[org 0x8000]
[bits 16]

; -----------------------------
; Kernel Entry Point
; -----------------------------
kernel_start:
    call cmd_clear
    
    ; Print welcome logo / header for login
    mov bx, MSG_LOGIN_HEADER
    call print_string

    ; Authenticate user before allowing access
    call do_login

; -----------------------------
; Terminal Loop
; -----------------------------
terminal_loop:
    mov bx, MSG_PROMPT
    call print_string
    
    call read_line

    ; If buffer is empty, just print prompt again
    cmp byte [input_buffer], 0
    je terminal_loop

    call execute_command
    jmp terminal_loop

; -----------------------------
; Input Routines
; -----------------------------
; Function: read_line
; Reads characters into input_buffer until Enter is pressed
read_line:
    pusha
    mov byte [buffer_index], 0
.loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D    ; Enter
    je .enter
    
    cmp al, 0x08    ; Backspace
    je .backspace
    
    cmp al, 32      ; Ignore other control chars
    jb .loop
    
    mov cl, [buffer_index]
    cmp cl, 63      ; Max buffer size
    jae .loop
    
    ; Store in buffer
    mov ch, 0
    mov bx, input_buffer
    add bx, cx
    mov [bx], al
    inc byte [buffer_index]
    
    ; Print char
    mov ah, 0x0E
    int 0x10
    jmp .loop
    
.backspace:
    cmp byte [buffer_index], 0
    je .loop
    dec byte [buffer_index]
    
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.enter:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    
    ; Null terminate
    mov cl, [buffer_index]
    mov ch, 0
    mov bx, input_buffer
    add bx, cx
    mov byte [bx], 0
    
    popa
    ret


; -----------------------------
; Command Execution
; -----------------------------
execute_command:
    mov si, input_buffer
    mov di, CMD_HELP
    call strcmp
    jc .do_help

    mov si, input_buffer
    mov di, CMD_INFO
    call strcmp
    jc .do_info

    mov si, input_buffer
    mov di, CMD_CLEAR
    call strcmp
    jc .do_clear

    mov si, input_buffer
    mov di, CMD_CALC
    call strcmp
    jc .do_calc

    mov bx, MSG_UNKNOWN
    call print_string
    ret

.do_help:
.do_info:
    mov bx, MSG_INFO
    call print_string
    ret

.do_clear:
    call cmd_clear
    ret

.do_calc:
    call cmd_calc
    ret

; -----------------------------
; Kernel Commands
; -----------------------------
cmd_clear:
    pusha
    mov ah, 0x00
    mov al, 0x03    ; Text mode 80x25
    int 0x10
    popa
    ret

; -----------------------------
; Utility Functions
; -----------------------------

; Function: atoi (ASCII to Integer)
; Input: SI = string
; Output: AX = integer
atoi:
    push bx
    push cx
    push dx
    xor ax, ax      ; Result = 0
    xor cx, cx
.loop:
    mov cl, [si]
    cmp cl, 0
    je .done
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    
    sub cl, '0'
    mov bx, 10
    mul bx
    add ax, cx
    
    inc si
    jmp .loop
.done:
    pop dx
    pop cx
    pop bx
    ret

; Function: itoa (Signed Integer to ASCII)
; Input: AX = signed integer, DI = output buffer
itoa:
    pusha
    mov cx, 0
    mov bx, 10
    
    ; Check if negative
    test ax, ax
    jns .loop1
    ; It is negative, insert '-' and make positive
    push ax
    mov al, '-'
    mov [di], al
    inc di
    pop ax
    neg ax
    
.loop1:
    xor dx, dx
    div bx          ; AX = AX / 10, DX = remainder
    push dx         ; push digit
    inc cx
    cmp ax, 0
    jne .loop1

.loop2:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    dec cx
    jnz .loop2

    mov byte [di], 0; null terminator
    popa
    ret

strcmp:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    popa
    clc
    ret
.equal:
    popa
    stc
    ret

print_string:
    pusha
    mov ah, 0x0E
.loop:
    mov al, [bx]
    cmp al, 0
    je .done
    int 0x10
    inc bx
    jmp .loop
.done:
    popa
    ret

; -----------------------------
; Kernel Data
; -----------------------------
MSG_KERNEL_START: db 'Welcome to NanoOS!', 13, 10, 'Type "help" or "info" for a list of commands.', 13, 10, 10, 0
MSG_PROMPT:       db 'NanoOS> ', 0
MSG_UNKNOWN:      db 'Unknown command. Type "help" for a list of commands.', 13, 10, 0
MSG_INFO:         db 'Available commands:', 13, 10, '  help   - Show this message', 13, 10, '  info   - Show this message', 13, 10, '  clear  - Clear the screen', 13, 10, '  calc   - Launch calculator', 13, 10, 0

CMD_HELP:         db 'help', 0
CMD_INFO:         db 'info', 0
CMD_CLEAR:        db 'clear', 0
CMD_CALC:         db 'calc', 0

buffer_index:     db 0
input_buffer:     times 64 db 0
output_buffer:    times 16 db 0

; -----------------------------
; Modules & Programs
; -----------------------------
%include "kernel/system/login.asm"
%include "kernel/programs/calc.asm"

; Pad kernel to exactly 5 sectors (5 * 512 = 2560 bytes)
times 2560-($-$$) db 0
