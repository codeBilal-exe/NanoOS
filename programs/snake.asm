; =====================================================
; NanoOS Snake Game
; File: snake.asm
; =====================================================

cmd_snake:
    pusha

    mov ax, 0x0003          ; Set Video Mode 03h (80x25 text mode)
    int 0x10

    ; --- Game Initialization ---
    mov word [snake_body], 0x0C28
    mov word [snake_body + 2], 0x0C27
    mov word [snake_body + 4], 0x0C26
    mov word [snake_len], 3
    mov byte [snake_dir], 1
    mov word [snake_food], 0x050A
    mov word [snake_score], 0
    mov byte [snake_exit_requested], 0

.game_loop:
    call snake_cls
    call snake_draw_all_borders
    call snake_draw_score
    call snake_draw_f
    call snake_draw_s
    call snake_input

    cmp byte [snake_exit_requested], 1
    je .quit

    call snake_move_tail
    call snake_move_head
    call snake_boundary_check
    jc .game_over
    call snake_eat_logic
    call snake_delay
    jmp .game_loop

.game_over:
    call snake_game_over

.quit:
    call cmd_clear
    popa
    ret

; --- Display Score Function ---
snake_draw_score:
    mov dx, 0x0002
    call snake_pos
    mov si, SNAKE_MSG_SCORE
    mov bl, 0x1E
    call snake_prt_c
    mov ax, [snake_score]
    call snake_p_num
    ret

; --- Draw Screen Borders ---
snake_draw_all_borders:
    mov bh, 0x1E
    mov ax, 0x0600
    xor cx, cx
    mov dx, 0x004F
    int 0x10
    mov cx, 0x1800
    mov dx, 0x184F
    int 0x10

    mov bl, 0x1E
    xor dx, dx
.side:
    call snake_pos
    mov al, '|'
    call snake_put_c
    mov dl, 79
    call snake_pos
    call snake_put_c
    xor dl, dl
    inc dh
    cmp dh, 25
    jne .side
    ret

; --- Collision Detection ---
snake_boundary_check:
    mov dx, [snake_body]
    cmp dl, 0
    jbe .hit
    cmp dl, 79
    jae .hit
    cmp dh, 0
    jbe .hit
    cmp dh, 24
    jae .hit
    clc
    ret
.hit:
    stc
    ret

; --- Game Over Screen ---
snake_game_over:
    mov ax, 0x0600
    mov bh, 0x4F
    xor cx, cx
    mov dx, 0x184F
    int 0x10

    mov dx, 0x0B22
    call snake_pos
    mov si, SNAKE_MSG_OVER
    mov bl, 0x4F
    call snake_prt_c

    mov dx, 0x0D1F
    call snake_pos
    mov si, SNAKE_MSG_FINAL
    mov bl, 0x4F
    call snake_prt_c
    mov ax, [snake_score]
    call snake_p_num

    mov dx, 0x0F1A
    call snake_pos
    mov si, SNAKE_MSG_EXIT
    mov bl, 0x4F
    call snake_prt_c

    xor ah, ah
    int 0x16
    ret

; --- Clear Screen Helper ---
snake_cls:
    mov ax, 0x0600
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    ret

; --- Draw Food ---
snake_draw_f:
    mov dx, [snake_food]
    call snake_pos
    mov al, '*'
    mov bl, 0x0C
    jmp snake_put_c

; --- Draw Snake ---
snake_draw_s:
    mov cx, [snake_len]
    mov si, snake_body
.ds:
    push cx
    mov dx, [si]
    call snake_pos
    mov al, '@'
    mov bl, 0x0B
    cmp si, snake_body
    jne .p
    mov bl, 0x0A
.p:
    call snake_put_c
    add si, 2
    pop cx
    loop .ds
    ret

; --- Keyboard Input Logic ---
snake_input:
    mov ah, 0x01
    int 0x16
    jz .r
    xor ah, ah
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    cmp al, 'w'
    je .su
    cmp al, 'W'
    je .su
    cmp al, 's'
    je .sd
    cmp al, 'S'
    je .sd
    cmp al, 'a'
    je .sl
    cmp al, 'A'
    je .sl
    cmp al, 'd'
    je .sr
    cmp al, 'D'
    je .sr
    ret
.su:
    mov byte [snake_dir], 0
    ret
.sd:
    mov byte [snake_dir], 2
    ret
.sl:
    mov byte [snake_dir], 3
    ret
.sr:
    mov byte [snake_dir], 1
    ret
.quit:
    mov byte [snake_exit_requested], 1
.r:
    ret

; --- Shift Body Segments ---
snake_move_tail:
    mov cx, [snake_len]
    mov di, snake_body
    mov ax, cx
    shl ax, 1
    add di, ax
.mt:
    mov ax, [di-2]
    mov [di], ax
    sub di, 2
    loop .mt
    ret

; --- Update Head Position ---
snake_move_head:
    mov ax, [snake_body]
    mov bl, [snake_dir]
    or bl, bl
    jz .mu
    cmp bl, 1
    je .mr
    cmp bl, 2
    je .md
    dec al
    jmp .mh
.mu:
    dec ah
    jmp .mh
.md:
    inc ah
    jmp .mh
.mr:
    inc al
.mh:
    mov [snake_body], ax
    ret

; --- Scoring & Food Logic ---
snake_eat_logic:
    mov ax, [snake_body]
    cmp ax, [snake_food]
    jne .r
    cmp word [snake_len], SNAKE_MAX_LEN
    jae .score_only
    inc word [snake_len]
.score_only:
    inc word [snake_score]
    add word [snake_food], 0x0102
    mov dx, [snake_food]
    and dx, 0x0F3F
    cmp dh, 1
    jae .row_ok
    mov dh, 5
.row_ok:
    cmp dl, 1
    jae .col_ok
    mov dl, 10
.col_ok:
    mov [snake_food], dx
.r:
    ret

; --- Frame Rate Timing (Delay) ---
snake_delay:
    xor ah, ah
    int 0x1A
    mov bx, dx
.dw:
    xor ah, ah
    int 0x1A
    sub dx, bx
    cmp dx, 4
    jl .dw
    ret

; --- BIOS Cursor Positioning ---
snake_pos:
    xor bh, bh
    mov ah, 0x02
    int 0x10
    ret

; --- Write Character with Attribute ---
snake_put_c:
    mov ah, 0x09
    xor bh, bh
    mov cx, 1
    int 0x10
    ret

snake_prt_c:
.l:
    lodsb
    or al, al
    jz .d
    mov ah, 0x09
    mov cx, 1
    int 0x10
    mov ah, 0x0E
    int 0x10
    jmp .l
.d:
    ret

snake_p_num:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    or ax, ax
    jz .s
    call snake_p_num
.s:
    pop dx
    mov al, dl
    add al, '0'
    mov ah, 0x0E
    int 0x10
    ret

; --- Data Area ---
SNAKE_MAX_LEN equ 25
SNAKE_MSG_SCORE: db 'Score: ', 0
SNAKE_MSG_OVER:  db 'GAME OVER', 0
SNAKE_MSG_FINAL: db 'Final Score: ', 0
SNAKE_MSG_EXIT:  db 'Press any key to return to NanoOS...', 0

snake_score:          dw 0
snake_dir:            db 0
snake_len:            dw 0
snake_food:           dw 0
snake_exit_requested: db 0
snake_body:           times SNAKE_MAX_LEN + 1 dw 0
