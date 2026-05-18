; =====================================================
; NanoOS BMI Calculator
; File: bmi.asm
; =====================================================

cmd_bmi:
    pusha

    mov ax, 0x0003          ; Set Video Mode (80x25 Text Mode)
    int 0x10

.main_bmi:
    call bmi_cls

    ; --- Title Section (Cyan Text) ---
    mov dx, 0x0105
    call bmi_pos
    mov bl, 0x0B
    mov si, BMI_MSG_TITLE
    call bmi_prt_c

    ; --- Age Input Section (Yellow Text) ---
    mov dx, 0x0305
    call bmi_pos
    mov bl, 0x0E
    mov si, BMI_MSG_AGE
    call bmi_prt_c
    call bmi_get_input
    mov [bmi_age], ax

    ; --- Weight Input Section (Yellow Text) ---
    mov dx, 0x0505
    call bmi_pos
    mov bl, 0x0E
    mov si, BMI_MSG_WEIGHT
    call bmi_prt_c
    call bmi_get_input
    mov [bmi_weight], ax

    ; --- Height Input Section (Yellow Text) ---
    mov dx, 0x0705
    call bmi_pos
    mov bl, 0x0E
    mov si, BMI_MSG_HEIGHT
    call bmi_prt_c
    call bmi_get_input
    mov [bmi_height], ax

    cmp word [bmi_height], 0
    je .bad_input

    ; --- BMI Calculation Logic (Fixed for 16-bit registers) ---
    ; Formula used: (Weight * 100) / ((Height * Height) / 100)
    mov ax, [bmi_weight]
    mov cx, 100
    mul cx
    mov si, ax
    mov di, dx

    mov ax, [bmi_height]
    mov bx, [bmi_height]
    mul bx
    mov bx, 100
    div bx

    cmp ax, 0
    je .bad_input

    mov bx, ax
    mov ax, si
    mov dx, di
    div bx
    mov [bmi_res], ax

    ; --- BMI Result Display (White Text) ---
    mov dx, 0x0905
    call bmi_pos
    mov bl, 0x0F
    mov si, BMI_MSG_RESULT
    call bmi_prt_c
    mov ax, [bmi_res]
    call bmi_p_num

    ; --- Status Logic (Categorizing the Result) ---
    mov dx, 0x0B05
    call bmi_pos
    mov ax, [bmi_res]
    mov bx, [bmi_age]

    cmp bx, 18
    jl .child
    cmp ax, 18
    jl .u
    cmp ax, 25
    jl .n
    jmp .o
.child:
    cmp ax, 15
    jl .u
    cmp ax, 22
    jl .n
.o:
    mov bl, 0x0C
    mov si, BMI_MSG_OVER
    jmp .sh
.u:
    mov bl, 0x09
    mov si, BMI_MSG_UNDER
    jmp .sh
.n:
    mov bl, 0x0A
    mov si, BMI_MSG_NORM
.sh:
    call bmi_prt_c
    jmp .wait_exit

.bad_input:
    mov dx, 0x0905
    call bmi_pos
    mov bl, 0x0C
    mov si, BMI_MSG_BAD_INPUT
    call bmi_prt_c

.wait_exit:
    ; --- Exit Message ---
    mov dx, 0x0D05
    call bmi_pos
    mov bl, 0x07
    mov si, BMI_MSG_EXIT
    call bmi_prt_c

    xor ah, ah
    int 0x16

    call cmd_clear
    popa
    ret

; --- HELPER FUNCTIONS ---

bmi_get_input:
    xor bx, bx
.next:
    xor ah, ah
    int 0x16
    cmp al, 13
    je .done
    cmp al, 8
    je .back
    sub al, '0'
    cmp al, 9
    ja .next
    mov cl, al
    mov ax, bx
    mov ch, 10
    mul ch
    xor ch, ch
    add ax, cx
    mov bx, ax
    add cl, '0'
    mov al, cl
    mov ah, 0x0E
    int 0x10
    jmp .next
.back:
    or bx, bx
    jz .next
    mov ax, 0x0E08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    mov ax, bx
    xor dx, dx
    mov cx, 10
    div cx
    mov bx, ax
    jmp .next
.done:
    mov ax, bx
    ret

bmi_prt_c:
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

bmi_pos:
    xor bh, bh
    mov ah, 0x02
    int 0x10
    ret

bmi_cls:
    mov ax, 0x0600
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    ret

bmi_p_num:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    or ax, ax
    jz .s
    call bmi_p_num
.s:
    pop dx
    mov al, dl
    add al, '0'
    mov ah, 0x0E
    int 0x10
    ret

; --- DATA SECTION ---
BMI_MSG_TITLE:     db 'BMI CALCULATOR', 0
BMI_MSG_AGE:       db 'Age: ', 0
BMI_MSG_WEIGHT:    db 'Weight(kg): ', 0
BMI_MSG_HEIGHT:    db 'Height(cm): ', 0
BMI_MSG_RESULT:    db 'BMI: ', 0
BMI_MSG_UNDER:     db 'STATUS: UNDERWEIGHT', 0
BMI_MSG_NORM:      db 'STATUS: NORMAL', 0
BMI_MSG_OVER:      db 'STATUS: OVERWEIGHT', 0
BMI_MSG_BAD_INPUT: db 'Invalid height. Please use centimeters above 0.', 0
BMI_MSG_EXIT:      db 'Any key to return to NanoOS...', 0

bmi_age:    dw 0
bmi_weight: dw 0
bmi_height: dw 0
bmi_res:    dw 0
