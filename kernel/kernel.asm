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
    mov di, CMD_CPU
    call strcmp
    jc .do_cpu

    mov si, input_buffer
    mov di, CMD_MEM
    call strcmp
    jc .do_mem

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

.do_cpu:
    call cmd_cpuinfo
    ret

.do_mem:
    call cmd_mem
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

.do_exit:
    call cmd_exit       ; does not return


; Function: run_program
; SI = pointer to program name string
run_program:
    mov di, PROG_CALC
    call strcmp_si
    jc .launch_calc

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


; -----------------------------
; Kernel Commands
; -----------------------------
cmd_help:
    pusha
    mov bx, MSG_BOX_TOP
    call print_string
    mov bx, MSG_INFO
    call print_string
    
    ; Show admin hint if admin
    cmp byte [is_admin], 1
    jne .no_admin_hint
    mov bx, MSG_ADMIN_HINT
    call print_string
.no_admin_hint:
    mov bx, MSG_BOX_BOTTOM
    call print_string
    popa
    ret

cmd_clear:
    pusha
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    popa
    ret

; logout: clear screen, reset is_admin, jump back to login
cmd_logout:
    mov byte [is_admin], 0  ; clear admin flag
    call cmd_clear
    ret

; exit: warm reboot via keyboard controller
cmd_exit:
    mov bx, MSG_EXIT
    call print_string
    ; Small delay loop
    mov cx, 0xFFFF
.delay:
    loop .delay
    ; Warm reboot: jump to FFFF:0000
    db 0xEA             ; far JMP opcode
    dw 0x0000           ; offset
    dw 0xFFFF           ; segment

cmd_cpuinfo:
    pusha
    mov eax, 0
    cpuid
    
    ; Vendor string is in EBX, EDX, ECX (12 bytes)
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0  ; Null terminate
    
    mov bx, MSG_CPU_VENDOR
    call print_string
    mov bx, cpu_vendor
    call print_string
    mov bx, MSG_NEWLINE
    call print_string
    popa
    ret

cmd_mem:
    pusha
    mov bx, MSG_MEM_TITLE
    call print_string
    
    ; Kernel Start
    mov bx, MSG_MEM_KERNEL
    call print_string
    mov ax, 0x8000
    call print_hex
    mov bx, MSG_NEWLINE
    call print_string
    
    ; User Database
    mov bx, MSG_MEM_USERS
    call print_string
    mov ax, USERS_DB
    call print_hex
    mov bx, MSG_NEWLINE
    call print_string
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
MSG_EXIT:         db 'Rebooting...', 13, 10, 0

MSG_BOX_TOP:      db '+-----------------------------------------+', 13, 10, 0
MSG_BOX_BOTTOM:   db '+-----------------------------------------+', 13, 10, 0
MSG_INFO:         db '| System Commands:                        |', 13, 10
                  db '|   help    - Show this message           |', 13, 10
                  db '|   clear   - Clear the screen            |', 13, 10
                  db '|   cpu     - Show CPU information        |', 13, 10
                  db '|   mem     - Show memory layout          |', 13, 10
                  db '|   logout  - Log out of session          |', 13, 10
                  db '|   exit    - Reboot the system           |', 13, 10
                  db '| Programs (use "run <name>"):            |', 13, 10
                  db '|   run calculator - Launch calculator    |', 13, 10, 0
MSG_ADMIN_HINT:   db '|   admin   - Show admin commands         |', 13, 10, 0
MSG_CPU_VENDOR:   db 'CPU Vendor: ', 0
MSG_MEM_TITLE:    db '--- System Memory Layout ---', 13, 10, 0
MSG_MEM_KERNEL:   db '  Kernel Start: 0x', 0
MSG_MEM_USERS:    db '  User DB:      0x', 0
MSG_RUN_UNKNOWN:  db 'run: program not found: ', 0

CMD_HELP:         db 'help', 0
CMD_INFO:         db 'info', 0
CMD_CLEAR:        db 'clear', 0
CMD_CALC:         db 'calc', 0
CMD_CPU:          db 'cpu', 0
CMD_MEM:          db 'mem', 0
CMD_LOGOUT:       db 'logout', 0
CMD_EXIT:         db 'exit', 0
CMD_RUN_PREFIX:   db 'run ', 0
CMD_ADMIN:        db 'admin', 0
CMD_USERS:        db 'users', 0
CMD_ADDUSER:      db 'adduser', 0
CMD_DELUSER:      db 'deluser', 0

PROG_CALC:        db 'calculator', 0

buffer_index:     db 0
input_buffer:     times 64 db 0
output_buffer:    times 16 db 0
cpu_vendor:       times 13 db 0
kernel_boot_drive:db 0x80    ; default hard disk; overwritten at boot

; -----------------------------
; Modules & Programs
; -----------------------------
%include "kernel/system/login.asm"
%include "kernel/system/admin.asm"
%include "kernel/programs/calc.asm"

; Pad kernel to exactly 16 sectors (16 * 512 = 8192 bytes)
times 8192-($-$$) db 0
