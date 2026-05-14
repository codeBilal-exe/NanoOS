; =====================================================
; NanoOS ASCII Animation Engine
; File: animate.asm
; 
; This module provides 3 animations:
;   1. Bouncing NanoOS Logo (DVD-style screensaver)
;   2. Starfield Warp (stars moving from center outward)
;   3. Matrix Rain (falling green characters)
;
; Entry point: call cmd_animate
; Uses: Direct Video RAM writes at 0xB800 for speed
; Exit: Press ESC during any animation, Q from menu
; =====================================================

; =====================================================
; MAIN ENTRY POINT
; =====================================================
cmd_animate:
    pusha

.menu:
    ; Clear screen using VRAM (fast)
    call anim_clear_vram

    ; Show cursor for menu
    mov ah, 0x01
    mov cx, 0x0607          ; Normal cursor shape
    int 0x10

    ; Set cursor to top-left
    mov ah, 0x02
    mov bh, 0
    mov dh, 0               ; Row 0
    mov dl, 0               ; Col 0
    int 0x10

    ; Print the menu
    mov bx, MSG_ANIM_MENU
    call print_string

    ; Wait for keypress (blocking)
    mov ah, 0x00
    int 0x16                ; AL = key pressed

    cmp al, '1'
    je .run_bounce
    cmp al, '2'
    je .run_stars
    cmp al, '3'
    je .run_matrix
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    cmp al, 27              ; ESC key
    je .quit
    jmp .menu               ; Invalid key, show menu again

.run_bounce:
    call anim_bounce
    jmp .menu

.run_stars:
    call anim_starfield
    jmp .menu

.run_matrix:
    call anim_matrix
    jmp .menu

.quit:
    ; Restore screen
    call anim_clear_vram
    ; Show cursor
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10
    ; Set cursor to top-left
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 0x10
    popa
    ret


; =====================================================
; ANIMATION 1: BOUNCING NANOOS LOGO
; A text string bounces around the 80x25 screen.
; Changes color every time it hits a wall.
; =====================================================
anim_bounce:
    pusha

    ; Initialize position and direction
    mov word [bounce_x], 10     ; Starting column
    mov word [bounce_y], 5      ; Starting row
    mov word [bounce_dx], 1     ; Moving right
    mov word [bounce_dy], 1     ; Moving down
    mov byte [bounce_color], 0x0E  ; Start with Yellow

    ; Hide cursor so it doesn't flicker
    mov ah, 0x01
    mov cx, 0x2607              ; Bit 5 of CH = hide cursor
    int 0x10

    ; Clear screen
    call anim_clear_vram

    ; Draw footer instruction
    mov ax, 24                  ; Row 24 (bottom)
    mov bx, 0                   ; Col 0
    mov si, MSG_ANIM_EXIT
    mov dl, 0x08                ; Dark gray color
    call vram_write_string

.loop:
    ; --- Check for keypress (NON-BLOCKING) ---
    mov ah, 0x01
    int 0x16                    ; ZF=1 if no key waiting
    jnz .exit_bounce            ; Key pressed? Exit!

    ; --- Step 1: Erase the logo at OLD position ---
    mov ax, [bounce_y]
    mov bx, [bounce_x]
    mov si, BOUNCE_TEXT
    mov dl, 0x00                ; Black = invisible (erase)
    call vram_write_string

    ; --- Step 2: Update X position ---
    mov ax, [bounce_x]
    add ax, [bounce_dx]         ; Move horizontally
    mov [bounce_x], ax

    ; --- Step 3: Update Y position ---
    mov ax, [bounce_y]
    add ax, [bounce_dy]         ; Move vertically
    mov [bounce_y], ax

    ; --- Step 4: Check X boundaries ---
    cmp word [bounce_x], 0
    jle .hit_left
    cmp word [bounce_x], BOUNCE_MAX_X
    jge .hit_right
    jmp .check_y

.hit_left:
    mov word [bounce_x], 0      ; Clamp to left edge
    mov word [bounce_dx], 1     ; Reverse: now moving right
    call bounce_next_color      ; Change color on wall hit
    jmp .check_y

.hit_right:
    mov word [bounce_x], BOUNCE_MAX_X
    mov word [bounce_dx], -1    ; Reverse: now moving left
    call bounce_next_color
    jmp .check_y

.check_y:
    cmp word [bounce_y], 0
    jle .hit_top
    cmp word [bounce_y], 23     ; Row 23 (row 24 = footer)
    jge .hit_bottom
    jmp .draw

.hit_top:
    mov word [bounce_y], 0
    mov word [bounce_dy], 1     ; Reverse: now moving down
    call bounce_next_color

    jmp .draw

.hit_bottom:
    mov word [bounce_y], 23
    mov word [bounce_dy], -1    ; Reverse: now moving up
    call bounce_next_color

.draw:
    ; --- Step 5: Draw logo at NEW position ---
    mov ax, [bounce_y]
    mov bx, [bounce_x]
    mov si, BOUNCE_TEXT
    mov dl, [bounce_color]
    call vram_write_string

    ; --- Step 6: Delay (~50ms = ~20 FPS) ---
    mov ah, 0x86
    mov cx, 0x0000              ; High word of microseconds
    mov dx, 0xC350              ; Low word = 50000 (50ms)
    int 0x15

    jmp .loop

.exit_bounce:
    ; Consume the keypress so it doesn't leak
    mov ah, 0x00
    int 0x16

    ; Restore cursor
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10

    popa
    ret


; Helper: Cycle to next bright color
bounce_next_color:
    push ax
    mov al, [bounce_color]
    and al, 0x0F                ; Get foreground nibble only
    inc al                      ; Next color
    cmp al, 16
    jb .check_skip
    mov al, 1                   ; Wrap around (skip 0 = black)
.check_skip:
    cmp al, 0                   ; Skip black
    je .skip
    cmp al, 8                   ; Skip dark gray (hard to see)
    jne .done
.skip:
    inc al
.done:
    mov [bounce_color], al      ; Background stays 0 (black)
    pop ax
    ret


; =====================================================
; ANIMATION 2: STARFIELD WARP
; Stars appear near center and fly outward in 8
; directions, simulating space travel / warp speed.
; =====================================================
NUM_STARS equ 20

anim_starfield:
    pusha

    ; Hide cursor
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    ; Clear screen
    call anim_clear_vram

    ; Initialize random seed from BIOS timer tick
    xor ax, ax
    mov es, ax
    mov ax, [es:0x046C]         ; BIOS tick count at 0000:046C
    mov [rand_seed], ax

    ; Initialize all stars at center
    mov cx, NUM_STARS
    xor bx, bx                 ; Index = 0
.init_stars:
    call star_reset             ; Reset star BX to center
    inc bx
    loop .init_stars

    ; Draw footer
    mov ax, 24
    mov bx, 0
    mov si, MSG_ANIM_EXIT
    mov dl, 0x08
    call vram_write_string

    ; --- Main Starfield Loop ---
.loop:
    ; Check for keypress (non-blocking)
    mov ah, 0x01
    int 0x16
    jnz .exit_stars

    ; Process each star
    mov cx, NUM_STARS
    xor bx, bx
.process_star:
    push cx                     ; Save loop counter

    ; --- Decrement this star's frame counter ---
    mov al, [star_count + bx]
    dec al
    mov [star_count + bx], al
    cmp al, 0
    jne .skip_star              ; Not time to move yet

    ; Reset counter to speed value
    mov al, [star_speed + bx]
    mov [star_count + bx], al

    ; --- Erase star at old position ---
    push bx
    movzx ax, byte [star_y + bx]
    movzx dx, byte [star_x + bx]
    ; Calculate VRAM offset = (row*80 + col)*2
    push dx
    mov cx, 80
    mul cx                      ; AX = row * 80
    pop dx
    add ax, dx                  ; AX = row*80 + col
    shl ax, 1                   ; AX = offset * 2
    mov di, ax
    push es
    push word 0xB800
    pop es
    mov byte [es:di], ' '       ; Erase character
    mov byte [es:di+1], 0x00    ; Black attribute
    pop es
    pop bx

    ; --- Move star: add direction to position ---
    ; Get direction index
    movzx si, byte [star_dir + bx]

    ; Look up dx, dy from direction table
    mov al, [dir_dx + si]       ; AL = dx (-1, 0, or +1)
    add [star_x + bx], al       ; Update X position
    mov al, [dir_dy + si]       ; AL = dy (-1, 0, or +1)
    add [star_y + bx], al       ; Update Y position

    ; --- Check bounds ---
    ; If X > 79 or Y > 23 (unsigned check catches underflow too)
    cmp byte [star_x + bx], 79
    ja .reset_this_star
    cmp byte [star_y + bx], 23
    ja .reset_this_star
    jmp .draw_star

.reset_this_star:
    call star_reset
    jmp .skip_star              ; Don't draw yet, will appear next frame

.draw_star:
    ; --- Draw star at new position ---
    push bx
    movzx ax, byte [star_y + bx]
    movzx dx, byte [star_x + bx]
    push dx
    mov cx, 80
    mul cx
    pop dx
    add ax, dx
    shl ax, 1
    mov di, ax
    push es
    push word 0xB800
    pop es
    mov al, [star_char + bx]    ; Character to draw
    mov [es:di], al
    mov ah, [star_color + bx]   ; Color attribute
    mov [es:di+1], ah
    pop es
    pop bx

.skip_star:
    pop cx                      ; Restore loop counter
    inc bx                      ; Next star index
    dec cx                      ; Manually decrement (loop body too large for short jump)
    jnz near .process_star      ; Use near jump to reach label

    ; --- Delay between frames (~40ms) ---
    mov ah, 0x86
    mov cx, 0x0000
    mov dx, 0x9C40              ; 40000 microseconds
    int 0x15

    jmp .loop

.exit_stars:
    mov ah, 0x00
    int 0x16                    ; Consume key
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10
    popa
    ret


; Helper: Reset star BX to center with random direction/speed
; Input: BX = star index
star_reset:
    push ax
    push cx
    push dx

    ; Position: near center (row=12, col=40)  +/- small random offset
    call rand_next
    and al, 0x03                ; Random 0-3
    add al, 39                  ; Col 39-42 (near center)
    mov [star_x + bx], al

    call rand_next
    and al, 0x01                ; Random 0-1
    add al, 11                  ; Row 11-12 (near center)
    mov [star_y + bx], al

    ; Direction: random 0-7
    call rand_next
    and al, 0x07                ; 8 directions
    mov [star_dir + bx], al

    ; Speed: 1, 2, or 3 (lower = faster)
    call rand_next
    and al, 0x03                ; 0-3
    inc al                      ; 1-4
    mov [star_speed + bx], al
    mov [star_count + bx], al   ; Initialize counter

    ; Character and color based on speed
    ; Fast stars: bright and big, slow stars: dim and small
    cmp al, 1
    je .fast
    cmp al, 2
    je .medium
    ; Slow (3-4)
    mov byte [star_char + bx], 0xFA  ; Middle dot (·)
    mov byte [star_color + bx], 0x08 ; Dark gray
    jmp .reset_done
.fast:
    mov byte [star_char + bx], '*'
    mov byte [star_color + bx], 0x0F ; Bright white
    jmp .reset_done
.medium:
    mov byte [star_char + bx], '+'
    mov byte [star_color + bx], 0x07 ; Light gray

.reset_done:
    pop dx
    pop cx
    pop ax
    ret


; =====================================================
; ANIMATION 3: MATRIX RAIN
; Green characters fall down columns, creating
; the iconic Matrix digital rain effect.
; =====================================================
NUM_RAIN_COLS equ 26          ; Use 26 columns spread across screen

anim_matrix:
    pusha

    ; Hide cursor
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    ; Clear screen
    call anim_clear_vram

    ; Seed random from BIOS timer
    xor ax, ax
    mov es, ax
    mov ax, [es:0x046C]
    mov [rand_seed], ax

    ; Initialize columns
    mov cx, NUM_RAIN_COLS
    xor bx, bx
.init_cols:
    ; Set screen column: spread across 80 columns
    ; Column positions: bx*3 (0, 3, 6, 9, ... 75)
    mov al, bl
    mov dl, 3
    mul dl                      ; AL = bx * 3
    mov [rain_col + bx], al     ; Store screen column

    ; Random starting Y position (stagger the drops)
    call rand_next
    and al, 0x1F                ; 0-31
    ; Use as negative offset (start above screen, wraps to high value)
    ; We'll treat values > 24 as "waiting to appear"
    mov [rain_y + bx], al

    ; Random speed (1-3)
    call rand_next
    and al, 0x01
    inc al                      ; 1-2
    mov [rain_speed + bx], al
    mov [rain_count + bx], al

    ; Tail length (4-7)
    call rand_next
    and al, 0x03
    add al, 4
    mov [rain_tail + bx], al

    inc bx
    loop .init_cols

    ; --- Main Matrix Loop ---
.loop:
    ; Check for keypress
    mov ah, 0x01
    int 0x16
    jnz .exit_matrix

    ; Process each column
    mov cx, NUM_RAIN_COLS
    xor bx, bx

.process_col:
    push cx

    ; Decrement counter
    mov al, [rain_count + bx]
    dec al
    mov [rain_count + bx], al
    cmp al, 0
    jne .skip_col               ; Not time to update

    ; Reset counter
    mov al, [rain_speed + bx]
    mov [rain_count + bx], al

    ; Get current Y and screen column
    movzx ax, byte [rain_y + bx]
    movzx dx, byte [rain_col + bx] ; DX = screen column

    ; --- If Y > 24, it's waiting (decrement toward 0) ---
    cmp al, 25
    jb .in_screen

    ; Still waiting above screen, just decrement
    dec byte [rain_y + bx]
    jmp .skip_col

.in_screen:
    ; --- Erase tail: clear the character (tail_len) rows above head ---
    push ax                     ; Save head Y
    push bx
    push dx

    movzx cx, byte [rain_tail + bx]
    mov ah, 0                   ; AH not needed here
    sub al, cl                  ; AL = Y - tail_length

    ; If this position is valid (0-24), erase it
    cmp al, 0
    jl .no_erase
    cmp al, 24
    ja .no_erase

    ; Calculate VRAM offset for erase position
    movzx si, al               ; SI = erase row
    push dx
    mov ax, si
    mov cx, 80
    mul cx                      ; AX = row * 80
    pop dx
    add ax, dx                  ; AX = row*80 + col
    shl ax, 1
    mov di, ax

    push es
    push word 0xB800
    pop es
    mov byte [es:di], ' '       ; Erase
    mov byte [es:di+1], 0x00
    pop es

.no_erase:
    pop dx
    pop bx
    pop ax                      ; Restore head Y

    ; --- Dim the character 1 row above head ---
    push ax
    push bx
    push dx

    cmp al, 0
    je .no_dim
    dec al                      ; Row above head

    cmp al, 24
    ja .no_dim

    ; VRAM offset for dim position
    movzx si, al
    push dx
    mov ax, si
    mov cx, 80
    mul cx
    pop dx
    add ax, dx
    shl ax, 1
    mov di, ax

    push es
    push word 0xB800
    pop es
    mov byte [es:di+1], 0x02    ; Dark green (was bright)
    pop es

.no_dim:
    pop dx
    pop bx
    pop ax

    ; --- Draw bright head character at current Y ---
    cmp al, 24
    ja .advance                 ; Off screen, don't draw

    push ax
    push bx
    push dx

    movzx si, al
    push dx
    mov ax, si
    mov cx, 80
    mul cx
    pop dx
    add ax, dx
    shl ax, 1
    mov di, ax

    ; Random character for head (A-Z range)
    call rand_next
    and al, 0x1F                ; 0-31
    add al, 'A'                 ; 'A' to '`' range
    cmp al, 'Z'
    jbe .char_ok
    sub al, 6                   ; Keep in A-Z range
.char_ok:
    push es
    push word 0xB800
    pop es
    mov [es:di], al             ; Random character
    mov byte [es:di+1], 0x0A    ; Bright green head
    pop es

    pop dx
    pop bx
    pop ax

.advance:
    ; Move head down by 1
    inc byte [rain_y + bx]

    ; Check if tail has fully passed screen bottom
    movzx ax, byte [rain_y + bx]
    movzx cx, byte [rain_tail + bx]
    sub al, cl                  ; Top of tail
    cmp al, 25                  ; If top of tail is past row 24
    jb .skip_col

    ; Reset this column: new random start position above screen
    call rand_next
    and al, 0x0F                ; 0-15
    add al, 26                  ; Start at 26-41 (above screen, will count down)
    mov [rain_y + bx], al

    ; New random speed
    call rand_next
    and al, 0x01
    inc al
    mov [rain_speed + bx], al

.skip_col:
    pop cx
    inc bx
    dec cx                      ; Manually decrement (loop body too large for short jump)
    jnz near .process_col      ; Use near jump to reach label

    ; --- Frame delay (~60ms) ---
    mov ah, 0x86
    mov cx, 0x0000
    mov dx, 0xEA60              ; 60000 microseconds
    int 0x15

    jmp .loop

.exit_matrix:
    mov ah, 0x00
    int 0x16
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10
    popa
    ret


; =====================================================
; SHARED HELPER FUNCTIONS
; =====================================================

; Function: vram_write_string
; Writes a string directly to Video RAM (fast, no flicker)
; Input: AX = row (0-24), BX = column (0-79)
;        SI = string address, DL = color attribute
vram_write_string:
    pusha
    push es

    ; Save color before MUL clobbers DX
    push dx

    ; Set ES to video memory segment
    push word 0xB800
    pop es

    ; Calculate offset: (row * 80 + col) * 2
    mov cx, 80
    mul cx                      ; AX = row * 80 (DX clobbered!)
    add ax, bx                  ; AX = row*80 + col
    shl ax, 1                   ; AX = byte offset
    mov di, ax                  ; DI = VRAM offset

    ; Restore color from stack
    pop dx                      ; DL = color attribute

.loop:
    lodsb                       ; AL = [DS:SI], SI++
    cmp al, 0
    je .done
    mov [es:di], al             ; Write character byte
    mov [es:di+1], dl           ; Write attribute byte
    add di, 2                   ; Move to next cell
    jmp .loop

.done:
    pop es
    popa
    ret


; Function: anim_clear_vram
; Fills entire 80x25 screen with spaces (black background)
anim_clear_vram:
    pusha
    push es

    push word 0xB800
    pop es

    xor di, di                  ; Start at offset 0
    mov cx, 2000                ; 80 * 25 = 2000 character cells
    mov ax, 0x0720              ; Space char (0x20) + gray-on-black (0x07)
    rep stosw                   ; Write AX to [ES:DI], DI+=2, CX--

    pop es
    popa
    ret





; =====================================================
; DIRECTION TABLES (for starfield)
; 8 compass directions: NW, N, NE, E, SE, S, SW, W
; Values are signed bytes: -1 (0xFF), 0, or +1
; =====================================================
dir_dx: db 0xFF, 0x00, 0x01, 0x01, 0x01, 0x00, 0xFF, 0xFF
;        NW     N      NE     E      SE     S      SW     W
dir_dy: db 0xFF, 0xFF, 0xFF, 0x00, 0x01, 0x01, 0x01, 0x00


; =====================================================
; DATA SECTION
; =====================================================

; --- Menu ---
MSG_ANIM_MENU:
    db '  ================================================', 13, 10
    db '  |       NanoOS ASCII Animation Engine           |', 13, 10
    db '  ================================================', 13, 10
    db '  |                                              |', 13, 10
    db '  |   [1]  Bouncing NanoOS Logo                  |', 13, 10
    db '  |   [2]  Starfield Warp                        |', 13, 10
    db '  |   [3]  Matrix Rain                           |', 13, 10
    db '  |                                              |', 13, 10
    db '  |   [Q]  Back to Shell                         |', 13, 10
    db '  |                                              |', 13, 10
    db '  ================================================', 13, 10
    db 13, 10
    db '  Select animation (1/2/3/Q): ', 0

MSG_ANIM_EXIT: db ' Press any key to stop animation...', 0

; --- Bouncing Logo Data ---
BOUNCE_TEXT: db ' ** NanoOS ** ', 0
BOUNCE_TEXT_LEN equ 14
BOUNCE_MAX_X equ 66               ; 80 - 14 = 66

bounce_x:     dw 10
bounce_y:     dw 5
bounce_dx:    dw 1
bounce_dy:    dw 1
bounce_color: db 0x0E              ; Yellow on black

; --- Starfield Data ---
star_x:       times NUM_STARS db 40
star_y:       times NUM_STARS db 12
star_dir:     times NUM_STARS db 0
star_speed:   times NUM_STARS db 1
star_count:   times NUM_STARS db 1
star_char:    times NUM_STARS db '*'
star_color:   times NUM_STARS db 0x0F

; --- Matrix Rain Data ---
rain_y:       times NUM_RAIN_COLS db 0
rain_col:     times NUM_RAIN_COLS db 0
rain_speed:   times NUM_RAIN_COLS db 1
rain_count:   times NUM_RAIN_COLS db 1
rain_tail:    times NUM_RAIN_COLS db 5


