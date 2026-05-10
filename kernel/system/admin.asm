; ==============================================
; Admin Module - NanoOS
; Only accessible when logged in as 'admin'
; ==============================================

; Function: cmd_admin_help
cmd_admin_help:
    pusha
    mov bx, MSG_ADMIN_HELP
    call print_string
    popa
    ret


; Function: cmd_list_users
; Prints every user entry from USERS_DB
cmd_list_users:
    pusha
    mov bx, MSG_USERS_TITLE
    call print_string
    
    mov bx, USERS_DB
.loop:
    mov al, [bx]
    cmp al, 0
    je .done
    cmp al, 13          ; skip \r
    je .advance
    
    ; Print character via TTY
    mov ah, 0x0E
    int 0x10
    
    ; After printing \n, also output \r so cursor goes to start of line
    cmp al, 10
    jne .advance
    mov al, 13
    int 0x10

.advance:
    inc bx
    jmp .loop
.done:
    mov bx, MSG_NEWLINE
    call print_string
    popa
    ret


; Function: cmd_add_user
; Prompts for username and password, appends to in-memory DB, writes to disk
cmd_add_user:
    pusha
    
    mov bx, MSG_ADD_USER_PROMPT
    call print_string
    call read_line
    ; Validate - don't allow empty username
    cmp byte [input_buffer], 0
    je .abort
    
    ; Save new username to admin_tmp_user
    mov si, input_buffer
    mov di, admin_tmp_user
    call strcpy
    
    mov bx, MSG_ADD_PASS_PROMPT
    call print_string
    call read_line
    ; Validate - don't allow empty password
    cmp byte [input_buffer], 0
    je .abort

    ; Find the null terminator in USERS_DB to know where to append
    mov di, USERS_DB
.find_end:
    mov al, [di]
    cmp al, 0
    je .found_end
    inc di
    jmp .find_end
    
.found_end:
    ; Safety check: ensure we don't overflow past USERS_DB_END
    ; (not strictly enforced here, just write and trust the 512 bytes)
    
    ; Write: username:password\n\0
    mov si, admin_tmp_user
.write_user:
    mov al, [si]
    cmp al, 0
    je .write_colon
    mov [di], al
    inc si
    inc di
    jmp .write_user
    
.write_colon:
    mov byte [di], ':'
    inc di
    
    mov si, input_buffer
.write_pass:
    mov al, [si]
    cmp al, 0
    je .write_newline
    mov [di], al
    inc si
    inc di
    jmp .write_pass
    
.write_newline:
    mov byte [di], 10   ; \n
    inc di
    mov byte [di], 0    ; new null terminator
    
    ; Write changes back to disk
    call save_users_to_disk
    
    mov bx, MSG_USER_ADDED
    call print_string
    popa
    ret
    
.abort:
    mov bx, MSG_USER_EMPTY
    call print_string
    popa
    ret


; Function: cmd_del_user
; Prompts for a username, removes that line from in-memory DB, writes to disk
cmd_del_user:
    pusha
    
    mov bx, MSG_DEL_USER_PROMPT
    call print_string
    call read_line
    
    cmp byte [input_buffer], 0
    je .abort

    ; Search for the user in USERS_DB
    mov bx, USERS_DB
.next_line:
    mov al, [bx]
    cmp al, 0
    je .not_found

    ; Try to match username at start of this line
    mov si, input_buffer
    mov di, bx
.cmp_user:
    mov al, [si]
    cmp al, 0
    je .check_colon     ; end of typed username
    mov dl, [di]
    cmp al, dl
    jne .skip_line
    inc si
    inc di
    jmp .cmp_user

.check_colon:
    mov dl, [di]
    cmp dl, ':'
    jne .skip_line      ; not a full match
    
    ; Found the user! Overwrite the entire line with spaces so parser skips it
.blank_line:
    mov al, [bx]
    cmp al, 0
    je .blanked
    cmp al, 10          ; stop at newline (keep it for line structure)
    je .blanked
    mov byte [bx], ' '
    inc bx
    jmp .blank_line
    
.blanked:
    call save_users_to_disk
    mov bx, MSG_USER_DELETED
    call print_string
    popa
    ret

.skip_line:
    ; Advance bx to the next line
    mov al, [bx]
    cmp al, 0
    je .not_found
    cmp al, 10
    je .advance_past_nl
    inc bx
    jmp .skip_line
.advance_past_nl:
    inc bx
    jmp .next_line

.not_found:
    mov bx, MSG_USER_NOT_FOUND
    call print_string
    popa
    ret
    
.abort:
    mov bx, MSG_USER_EMPTY
    call print_string
    popa
    ret


; Function: save_users_to_disk
; Writes the sectors containing USERS_DB back to the disk image (os.bin via QEMU)
; This makes adduser/deluser persist across reboots
save_users_to_disk:
    pusha
    
    ; Compute which disk sector USERS_DB starts at (runtime calculation)
    ; Kernel is loaded at 0x8000, starts at disk sector 2 (sector 1 = bootloader)
    mov ax, USERS_DB
    sub ax, 0x8000          ; byte offset of USERS_DB from kernel base
    mov cx, 512
    xor dx, dx
    div cx                  ; AX = sector index within kernel (0-based)
    add ax, 2               ; disk sector number (2 = first kernel sector)
    mov cl, al              ; CL = starting sector for INT 13h

    ; Compute the sector-aligned memory address to write from
    mov ax, USERS_DB
    and ax, 0xFE00          ; zero the lower 9 bits (align down to 512)
    mov bx, ax              ; BX = sector-aligned buffer address

    ; Write 2 sectors to cover USERS_DB + runtime extra space
    xor ax, ax
    mov es, ax              ; ES = 0 (segment)
    mov ah, 0x03            ; BIOS: write sectors
    mov al, 2               ; write 2 sectors
    mov ch, 0               ; cylinder 0
    mov dh, 0               ; head 0
    mov dl, [kernel_boot_drive]
    int 0x13
    
    popa
    ret


; -----------------------------
; Admin Data
; -----------------------------
MSG_ADMIN_HELP:     db '+=== Admin Commands ===================+', 13, 10
                    db '| admin          - Show this menu      |', 13, 10
                    db '| users          - List all users      |', 13, 10
                    db '| adduser        - Add a new user      |', 13, 10
                    db '| deluser        - Delete a user       |', 13, 10
                    db '+======================================+', 13, 10, 0

MSG_USERS_TITLE:    db '--- Registered Users ---', 13, 10, 0
MSG_ADD_USER_PROMPT:db 'New username: ', 0
MSG_ADD_PASS_PROMPT:db 'New password: ', 0
MSG_USER_ADDED:     db 'User added and saved to disk.', 13, 10, 0
MSG_DEL_USER_PROMPT:db 'Delete username: ', 0
MSG_USER_DELETED:   db 'User deleted and saved to disk.', 13, 10, 0
MSG_USER_NOT_FOUND: db 'Error: User not found.', 13, 10, 0
MSG_USER_EMPTY:     db 'Error: Field cannot be empty.', 13, 10, 0

admin_tmp_user:     times 64 db 0
