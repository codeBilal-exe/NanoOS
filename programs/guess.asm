; =====================================================
; NanoOS Number Guessing Game
; File: guess.asm
; =====================================================

cmd_guess:
    pusha
    call cmd_clear
    
    ; Print Header
    mov bx, MSG_GUESS_HDR
    call print_string
    
    ; Generate random number 1-100
    call rand_next
    xor dx, dx
    mov cx, 100
    div cx              ; DX = AX % 100 (remainder in DX)
    inc dx              ; DX = 1 to 100
    mov [target_num], dx
    mov word [guess_count], 0

.game_loop:
    mov bx, MSG_GUESS_PROMPT
    call print_string
    
    call read_line
    
    ; If empty, just repeat
    cmp byte [input_buffer], 0
    je .game_loop
    
    ; Check for 'q'
    mov al, [input_buffer]
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    
    ; Convert input to integer
    mov si, input_buffer
    call atoi           ; AX = integer value
    
    inc word [guess_count]
    
    mov bx, [target_num]
    cmp ax, bx
    je .win
    jl .higher
    jg .lower

.higher:
    mov bx, MSG_GUESS_HIGHER
    call print_string
    jmp .game_loop
    
.lower:
    mov bx, MSG_GUESS_LOWER
    call print_string
    jmp .game_loop
    
.win:
    mov bx, MSG_GUESS_WIN
    call print_string
    
    ; Convert guess count to string for display
    mov ax, [guess_count]
    mov di, output_buffer
    call itoa
    mov bx, output_buffer
    call print_string
    
    mov bx, MSG_GUESS_TRIES
    call print_string
    
    ; Wait for key before returning
    mov ah, 0x00
    int 0x16
    jmp .quit

.quit:
    popa
    ret

; -----------------------------
; Data Section
; -----------------------------
MSG_GUESS_HDR:    db 13, 10, '  ================================================', 13, 10
                  db '  |          NanoOS Number Guessing Game         |', 13, 10
                  db '  ================================================', 13, 10
                  db '  I have picked a number between 1 and 100.', 13, 10
                  db '  Can you guess it? (Type "q" to exit)', 13, 10, 10, 0
MSG_GUESS_PROMPT: db '  Enter your guess: ', 0
MSG_GUESS_HIGHER: db '  >> TOO LOW! Try a higher number.', 13, 10, 0
MSG_GUESS_LOWER:  db '  >> TOO HIGH! Try a lower number.', 13, 10, 0
MSG_GUESS_WIN:    db 13, 10, '  [!] CONGRATULATIONS! You found it in ', 0
MSG_GUESS_TRIES:  db ' tries.', 13, 10, 13, 10, '  [Press any key to return to shell]', 0

target_num:  dw 0
guess_count: dw 0
