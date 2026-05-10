; -----------------------------
; System Login Module
; -----------------------------

do_login:
.login_loop:
    ; Ask for Username
    mov bx, MSG_LOGIN_USER
    call print_string
    call read_line
    
    ; Save username to user_buffer
    mov si, input_buffer
    mov di, user_buffer
    call strcpy
    
    ; Ask for Password
    mov bx, MSG_LOGIN_PASS
    call print_string
    call read_password
    
    ; Password is now in input_buffer
    ; Verify credentials against USERS_DB
    call verify_credentials
    jc .login_success
    
.login_failed:
    mov bx, MSG_LOGIN_FAIL
    call print_string
    jmp .login_loop

.login_success:
    ; Check if the logged-in user is 'admin' and set flag
    mov si, user_buffer
    mov di, STR_ADMIN
    call strcmp
    jnc .not_admin
    mov byte [is_admin], 1
.not_admin:
    call cmd_clear
    mov bx, MSG_KERNEL_START
    call print_string
    
    ; Show admin notice if applicable
    cmp byte [is_admin], 1
    jne .done
    mov bx, MSG_ADMIN_LOGIN
    call print_string
.done:
    ret


; Function: verify_credentials
; Checks if user_buffer:input_buffer exists in USERS_DB
; Returns CF=1 if success, CF=0 if failed
verify_credentials:
    pusha
    mov bx, USERS_DB
.next_line:
    mov al, [bx]
    cmp al, 0
    je .fail         ; End of DB, not found

    ; Compare username
    mov si, user_buffer
    mov di, bx
.cmp_user:
    mov al, [si]
    cmp al, 0
    je .user_matched ; User string ended, let's check if DB has ':' here
    
    mov dl, [di]
    cmp al, dl
    jne .skip_line   ; Mismatch
    
    inc si
    inc di
    jmp .cmp_user

.user_matched:
    mov dl, [di]
    cmp dl, ':'
    jne .skip_line   ; Not a perfect match
    
    ; Username matched! Skip the ':'
    inc di

    ; Compare password
    mov si, input_buffer
.cmp_pass:
    mov al, [si]
    cmp al, 0
    je .pass_matched ; Password string ended, let's check if DB has \r or \n or 0
    
    mov dl, [di]
    cmp al, dl
    jne .skip_line   ; Mismatch
    
    inc si
    inc di
    jmp .cmp_pass

.pass_matched:
    mov dl, [di]
    cmp dl, 13       ; \r
    je .success
    cmp dl, 10       ; \n
    je .success
    cmp dl, 0        ; end of string
    je .success
    
    ; Otherwise, mismatch
    jmp .skip_line

.skip_line:
    ; Read until \n or 0
    mov al, [bx]
    cmp al, 0
    je .fail
    cmp al, 10
    je .found_nl
    inc bx
    jmp .skip_line
.found_nl:
    inc bx           ; Skip \n
    jmp .next_line

.success:
    popa
    stc
    ret
.fail:
    popa
    clc
    ret


; Function: strcpy
; Copies null-terminated string from SI to DI
strcpy:
    pusha
.loop:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je .done
    inc si
    inc di
    jmp .loop
.done:
    popa
    ret


; Function: read_password
; Reads characters into input_buffer, but prints '*' instead of the character
read_password:
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
    
    ; Store actual char in buffer
    mov ch, 0
    mov bx, input_buffer
    add bx, cx
    mov [bx], al
    inc byte [buffer_index]
    
    ; Print '*' instead of char
    mov ah, 0x0E
    mov al, '*'
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
; Login Data
; -----------------------------
MSG_LOGIN_HEADER: db 'NanoOS User Authentication', 13, 10, 10, 0
MSG_LOGIN_USER:   db 'Username: ', 0
MSG_LOGIN_PASS:   db 'Password: ', 0
MSG_LOGIN_FAIL:   db 'Access Denied.', 13, 10, 10, 0
MSG_ADMIN_LOGIN:  db '[Admin] You have administrator privileges.', 13, 10
                  db '        Type "admin" to see admin commands.', 13, 10, 10, 0

STR_ADMIN:        db 'admin', 0

user_buffer:      times 64 db 0

USERS_DB:
    incbin "kernel/system/users.txt"
USERS_DB_RUNTIME_END:       ; marker: where runtime data starts
    times 512 db 0          ; extra writable space for adduser (in-memory + disk)
USERS_DB_END equ $          ; marker: total end
