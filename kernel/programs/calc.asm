; -----------------------------
; Calculator Program
; -----------------------------
cmd_calc:
    ; Num 1
    mov bx, MSG_CALC_NUM1
    call print_string
    call read_line
    mov si, input_buffer
    call atoi
    mov [calc_num1], ax
    
    ; Operator
    mov bx, MSG_CALC_OP
    call print_string
    call read_line
    mov al, [input_buffer]
    mov [calc_op], al
    
    ; Num 2
    mov bx, MSG_CALC_NUM2
    call print_string
    call read_line
    mov si, input_buffer
    call atoi
    mov [calc_num2], ax
    
    ; Calculate
    mov ax, [calc_num1]
    mov bx, [calc_num2]
    mov cl, [calc_op]
    
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .sub
    cmp cl, '*'
    je .mul
    cmp cl, '/'
    je .div
    
    mov bx, MSG_CALC_ERR
    call print_string
    ret

.add:
    add ax, bx
    jmp .print
.sub:
    sub ax, bx
    jmp .print
.mul:
    imul bx
    jmp .print
.div:
    cmp bx, 0
    je .div0
    cwd             ; sign extend AX into DX for idiv
    idiv bx
    jmp .print

.div0:
    mov bx, MSG_CALC_DIV0
    call print_string
    ret

.print:
    mov di, output_buffer
    call itoa
    
    mov bx, MSG_CALC_RES
    call print_string
    mov bx, output_buffer
    call print_string
    
    ; Print newline
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

; -----------------------------
; Calculator Data
; -----------------------------
MSG_CALC_NUM1:    db 'Enter first number: ', 0
MSG_CALC_OP:      db 'Enter operator (+, -, *, /): ', 0
MSG_CALC_NUM2:    db 'Enter second number: ', 0
MSG_CALC_ERR:     db 'Error: Invalid operator.', 13, 10, 0
MSG_CALC_DIV0:    db 'Error: Division by zero.', 13, 10, 0
MSG_CALC_RES:     db 'Result: ', 0

calc_num1:        dw 0
calc_num2:        dw 0
calc_op:          db 0
