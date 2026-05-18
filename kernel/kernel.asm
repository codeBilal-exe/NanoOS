[org 0x8000]
[bits 16]

; -----------------------------
; Kernel Entry Point
; -----------------------------
kernel_start:
    ; Read boot drive number saved by bootloader at 0x7E00
    mov al, [0x7E00]
    mov [kernel_boot_drive], al

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
    ; Print prompt in Cyan (Color 0x0B)
    mov si, MSG_PROMPT
    mov bl, 0x0B
    call print_string_color
    
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
    ; --- System Commands ---
    mov si, input_buffer
    mov di, CMD_HELP
    call strcmp
    jc .do_help

    mov si, input_buffer
    mov di, CMD_INFO
    call strcmp
    jc .do_help

    mov si, input_buffer
    mov di, CMD_CLEAR
    call strcmp
    jc .do_clear

    mov si, input_buffer
    mov di, CMD_LS
    call strcmp
    jc .do_ls

    ; --- run <program> command ---
    mov si, input_buffer
    mov di, CMD_RUN_PREFIX
    call str_startswith
    jc .do_run

    mov si, input_buffer
    mov di, CMD_LOGOUT
    call strcmp
    jc .do_logout

    mov si, input_buffer
    mov di, CMD_RESTART
    call strcmp
    jc .do_restart

    mov si, input_buffer
    mov di, CMD_EXIT
    call strcmp
    jc .do_exit

    ; --- Admin-only Commands (check privilege first) ---
    cmp byte [is_admin], 1
    jne .not_admin

    mov si, input_buffer
    mov di, CMD_ADMIN
    call strcmp
    jc .do_admin_help

    mov si, input_buffer
    mov di, CMD_USERS
    call strcmp
    jc .do_users

    mov si, input_buffer
    mov di, CMD_ADDUSER
    call strcmp
    jc .do_adduser

    mov si, input_buffer
    mov di, CMD_DELUSER
    call strcmp
    jc .do_deluser

.not_admin:
    mov bx, MSG_UNKNOWN
    call print_string
    ret

; --- Handlers ---
.do_help:
    call cmd_help
    ret

.do_clear:
    call cmd_clear
    ret

.do_ls:
    call cmd_ls
    ret

.do_admin_help:
    call cmd_admin_help
    ret

.do_users:
    call cmd_list_users
    ret

.do_adduser:
    call cmd_add_user
    ret

.do_deluser:
    call cmd_del_user
    ret

.do_run:
    ; Strip "run " (4 chars) and dispatch to program launcher
    mov si, input_buffer
    add si, 4           ; Skip past "run "
    call run_program
    ret

.do_logout:
    call cmd_logout
    jmp kernel_start    ; jump back to top — do_login will be called again

.do_restart:
    call cmd_restart    ; does not return

.do_exit:
    call cmd_exit       ; does not return


; Function: run_program
; SI = pointer to program name string
run_program:
    mov di, PROG_CALC
    call strcmp_si
    jc .launch_calc

    mov di, PROG_ANIMATE
    call strcmp_si
    jc .launch_animate

    mov di, PROG_MEMORY
    call strcmp_si
    jc .launch_memory

    mov di, PROG_GUESS
    call strcmp_si
    jc .launch_guess

    mov di, PROG_SNAKE
    call strcmp_si
    jc .launch_snake

    mov di, PROG_BMI
    call strcmp_si
    jc .launch_bmi

    ; Unknown program
    mov bx, MSG_RUN_UNKNOWN
    call print_string
    ; Print what they tried
    push si
    mov bx, si
    call print_string
    pop si
    mov bx, MSG_NEWLINE
    call print_string
    ret

.launch_calc:
    call cmd_calc
    ret

.launch_animate:
    call cmd_animate
    ret

.launch_memory:
    call cmd_memory
    ret

.launch_guess:
    call cmd_guess
    ret

.launch_snake:
    call cmd_snake
    ret

.launch_bmi:
    call cmd_bmi
    ret


; -----------------------------
; Kernel Commands
; -----------------------------
cmd_help:
    pusha
    mov bx, MSG_HELP_HEADER
    call print_string
    
    mov bx, MSG_HELP_SYS
    call print_string
    
    mov bx, MSG_HELP_PROG
    call print_string

    ; Show admin section if admin
    cmp byte [is_admin], 1
    jne .help_done
    mov bx, MSG_HELP_ADMIN
    call print_string
.help_done:
    mov bx, MSG_HELP_FOOTER
    call print_string
    popa
    ret

cmd_ls:
    pusha
    mov bx, MSG_LS_HEADER
    call print_string
    mov bx, MSG_PROG_LIST
    call print_string
    popa
    ret

cmd_clear:
    pusha
    mov ah, 0x06        ; Scroll up function
    xor al, al          ; Clear whole screen
    xor cx, cx          ; Top-left (0,0)
    mov dx, 0x184F      ; Bottom-right (24,79)
    mov bh, 0x07        ; Normal attribute (gray on black)
    int 0x10

    ; Set cursor to top-left
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 0x10
    popa
    ret

; logout: clear screen, reset is_admin, jump back to login
cmd_logout:
    mov byte [is_admin], 0  ; clear admin flag
    call cmd_clear
    ret

; restart: warm reboot via BIOS jump
cmd_restart:
    mov bx, MSG_RESTART
    call print_string
    ; Small delay loop
    mov cx, 0xFFFF
.delay:
    loop .delay
    ; Warm reboot: jump to FFFF:0000
    db 0xEA             ; far JMP opcode
    dw 0x0000           ; offset
    dw 0xFFFF           ; segment
    ret

; exit: attempts to shut down the machine via APM
cmd_exit:
    mov bx, MSG_SHUTDOWN
    call print_string

    ; 1. Connect to APM
    mov ax, 0x5301
    xor bx, bx
    int 0x15

    ; 2. Enable APM for all devices
    mov ax, 0x5308
    mov bx, 0x0001
    mov cx, 0x0001
    int 0x15

    ; 3. Set power state to off (shutdown)
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15

    ; If APM fails (older BIOS/unsupported), print fallback and halt
    mov bx, MSG_SHUTDOWN_FAIL
    call print_string
    hlt
    jmp $

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
    xor ax, ax
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
    test ax, ax
    jns .loop1
    push ax
    mov al, '-'
    mov [di], al
    inc di
    pop ax
    neg ax
.loop1:
    xor dx, dx
    div bx
    push dx
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
    mov byte [di], 0
    popa
    ret

; Function: strcmp
; SI = string1, DI = string2
; CF=1 if equal, CF=0 if not
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

; Function: strcmp_si
; SI = string1 (already pointing), DI = string2
; CF=1 if equal, CF=0 if not
; Note: does NOT modify SI before returning so caller can reuse
strcmp_si:
    pusha
    push si         ; Save original SI
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
    pop si
    popa
    clc
    ret
.equal:
    pop si
    popa
    stc
    ret

; Function: str_startswith
; SI = haystack, DI = prefix
; CF=1 if SI starts with DI
str_startswith:
    pusha
.loop:
    mov al, [di]
    cmp al, 0
    je .match       ; Reached end of prefix = full match
    mov bl, [si]
    cmp al, bl
    jne .no_match
    inc si
    inc di
    jmp .loop
.match:
    popa
    stc
    ret
.no_match:
    popa
    clc
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

; Function: print_string_color
; SI = string address, BL = attribute (color)
print_string_color:
    pusha
    mov ah, 0x09
    mov bh, 0
    mov cx, 1
.loop:
    mov al, [si]
    cmp al, 0
    je .done
    int 0x10
    push bx
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop bx
    mov ah, 0x09
    inc si
    jmp .loop
.done:
    popa
    ret

; Function: print_char
; Input: AL = character to print
print_char:
    pusha
    mov ah, 0x0E
    int 0x10
    popa
    ret

; Function: print_newline
print_newline:
    pusha
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    popa
    ret

; Function: print_hex_byte
; Prints AL as 2-digit hex
print_hex_byte:
    pusha
    mov cl, al
    shr al, 4
    call .nibble
    mov al, cl
    and al, 0x0F
    call .nibble
    popa
    ret
.nibble:
    cmp al, 9
    jbe .digit_n
    add al, 'A' - 10
    jmp .out_n
.digit_n:
    add al, '0'
.out_n:
    mov ah, 0x0E
    int 0x10
    ret

; Function: print_hex_word
; Prints AX as 4-digit hex
print_hex_word:
    pusha
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    popa
    ret

; Function: print_hex
; Prints AX as 4-digit hex
print_hex:
    pusha
    mov cx, 4
.loop:
    push ax
    mov dx, cx
    dec dx
    shl dx, 2
    mov cl, dl
    shr ax, cl
    and ax, 0x000F
    cmp al, 9
    jbe .digit
    add al, 7
.digit:
    add al, '0'
    mov ah, 0x0E
    int 0x10
    pop ax
    mov cx, dx
    shr cx, 2
    inc cx
    loop .loop
    popa
    ret

; Function: rand_next
; Simple pseudo-random number generator (Linear Congruential)
; Output: AX = pseudo-random 16-bit number
rand_next:
    push cx
    push dx
    mov ax, [rand_seed]
    mov cx, 25173               ; Multiplier
    mul cx                      ; DX:AX = seed * 25173
    add ax, 13849               ; Add constant
    mov [rand_seed], ax         ; Save new seed
    pop dx
    pop cx
    ret                         ; AX = random number

; -----------------------------
; Kernel Data
; -----------------------------
is_admin:         db 0   ; 1 if logged in as admin

MSG_KERNEL_START: db 'Welcome to NanoOS!', 13, 10
                  db 'Type "help" for commands.', 13, 10
                  db 'Run programs: run calculator', 13, 10, 10, 0
MSG_PROMPT:       db 'NanoOS> ', 0
MSG_NEWLINE:      db 13, 10, 0
MSG_UNKNOWN:      db 'Unknown command. Type "help" for a list.', 13, 10, 0
MSG_RESTART:       db 'Rebooting NanoOS...', 13, 10, 0
MSG_SHUTDOWN:      db 'Shutting down NanoOS...', 13, 10, 0
MSG_SHUTDOWN_FAIL: db 'Shutdown failed. You can safely turn off your PC.', 13, 10, 0

MSG_HELP_HEADER:   db 13, 10, '  NanoOS Professional Edition - Command Reference', 13, 10
                    db '  ================================================', 13, 10, 0
MSG_HELP_SYS:      db '  [ SYSTEM ]', 13, 10
                    db '    ls       - List available programs', 13, 10
                    db '    run      - Execute a program (usage: run <name>)', 13, 10
                    db '    clear    - Clear terminal buffer', 13, 10
                    db '    logout   - Terminate current session', 13, 10
                    db '    restart  - Perform system reboot', 13, 10
                    db '    exit     - Shutdown NanoOS', 13, 10, 0
MSG_HELP_PROG:     db 13, 10, '  [ PROGRAMS ]', 13, 10
                    db '    Use "ls" to view installed applications.', 13, 10, 0
MSG_HELP_ADMIN:    db 13, 10, '  [ ADMINISTRATIVE ]', 13, 10
                    db '    users    - List registered users', 13, 10
                    db '    adduser  - Register new system user', 13, 10
                    db '    deluser  - Remove existing system user', 13, 10, 0
MSG_HELP_FOOTER:   db '  ================================================', 13, 10, 0

MSG_LS_HEADER:     db 13, 10, '  Installed Programs:', 13, 10
                    db '  ------------------', 13, 10, 0
MSG_PROG_LIST:     db '  - calculator', 13, 10
                    db '  - animate', 13, 10
                    db '  - memory', 13, 10
                    db '  - guess', 13, 10
                    db '  - snake', 13, 10
                    db '  - bmi', 13, 10, 13, 10, 0
MSG_RUN_UNKNOWN:  db 'run: program not found: ', 0

CMD_HELP:         db 'help', 0
CMD_INFO:         db 'info', 0
CMD_CLEAR:        db 'clear', 0
CMD_LS:           db 'ls', 0
CMD_LOGOUT:       db 'logout', 0
CMD_RESTART:      db 'restart', 0
CMD_EXIT:         db 'exit', 0
CMD_RUN_PREFIX:   db 'run ', 0
CMD_ADMIN:        db 'admin', 0
CMD_USERS:        db 'users', 0
CMD_ADDUSER:      db 'adduser', 0
CMD_DELUSER:      db 'deluser', 0

PROG_CALC:        db 'calculator', 0
PROG_ANIMATE:     db 'animate', 0
PROG_MEMORY:      db 'memory', 0
PROG_GUESS:       db 'guess', 0
PROG_SNAKE:       db 'snake', 0
PROG_BMI:         db 'bmi', 0
rand_seed:        dw 0x3A7F

buffer_index:     db 0
input_buffer:     times 64 db 0
output_buffer:    times 16 db 0
kernel_boot_drive:db 0x80    ; default hard disk; overwritten at boot

; -----------------------------
; Modules & Programs
; -----------------------------
%include "kernel/system/login.asm"
%include "kernel/system/admin.asm"
%include "programs/calculator.asm"
%include "programs/animate.asm"
%include "programs/memory.asm"
%include "programs/guess.asm"
%include "programs/snake.asm"
%include "programs/bmi.asm"

; Pad kernel to 128 sectors (128 * 512 = 65536 bytes)
times 65536-($-$$) db 0
