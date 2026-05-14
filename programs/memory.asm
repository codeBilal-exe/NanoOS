; =====================================================
; NanoOS Memory Visualization Tool
; File: memory.asm
;
; Sub-views:
;   1. Memory Map     - System memory layout
;   2. Register View  - CPU register values
;   3. Stack View     - Stack contents
;   4. Hex Dump       - Inspect any memory address
;   5. Flags View     - CPU flags decoded
;   6. Live Demo      - Watch operations step by step
;
; Entry: call cmd_memory
; =====================================================

cmd_memory:
    ; === CAPTURE REGISTERS IMMEDIATELY (before anything changes them) ===
    mov [saved_sp], sp
    mov [saved_bp], bp
    mov [saved_ax], ax
    mov [saved_bx], bx
    mov [saved_cx], cx
    mov [saved_dx], dx
    mov [saved_si], si
    mov [saved_di], di
    mov [saved_cs], cs
    mov [saved_ds], ds
    mov [saved_es], es
    mov [saved_ss], ss
    pushf
    pop word [saved_flags]

    pusha

.menu:
    call cmd_clear

    ; Print menu
    mov bx, MSG_MEM_MENU
    call print_string

    ; Wait for key
    mov ah, 0x00
    int 0x16

    cmp al, '1'
    je .do_map
    cmp al, '2'
    je .do_regs
    cmp al, '3'
    je .do_stack
    cmp al, '4'
    je .do_dump
    cmp al, '5'
    je .do_flags
    cmp al, '6'
    je .do_demo
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    cmp al, 27
    je .quit
    jmp .menu

.do_map:
    call mem_show_map
    jmp .menu
.do_regs:
    call mem_show_regs
    jmp .menu
.do_stack:
    call mem_show_stack
    jmp .menu
.do_dump:
    call mem_hex_dump
    jmp .menu
.do_flags:
    call mem_show_flags
    jmp .menu
.do_demo:
    call mem_live_demo
    jmp .menu

.quit:
    popa
    ret


; =====================================================
; VIEW 1: MEMORY MAP
; =====================================================
mem_show_map:
    pusha
    call cmd_clear

    mov bx, MSG_MAP
    call print_string

    ; Wait for key to return
    mov ah, 0x00
    int 0x16
    popa
    ret


; =====================================================
; VIEW 2: REGISTER VIEW
; =====================================================
mem_show_regs:
    pusha
    call cmd_clear

    mov bx, MSG_REG_TITLE
    call print_string

    ; -- General Purpose Registers --
    mov bx, MSG_R_AX
    call print_string
    mov ax, [saved_ax]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_BX
    call print_string
    mov ax, [saved_bx]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_CX
    call print_string
    mov ax, [saved_cx]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_DX
    call print_string
    mov ax, [saved_dx]
    call print_hex_word
    call print_newline

    ; -- Pointer Registers --
    mov bx, MSG_SEP1
    call print_string

    mov bx, MSG_R_SP
    call print_string
    mov ax, [saved_sp]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_BP
    call print_string
    mov ax, [saved_bp]
    call print_hex_word
    call print_newline

    ; -- Index Registers --
    mov bx, MSG_R_SI
    call print_string
    mov ax, [saved_si]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_DI
    call print_string
    mov ax, [saved_di]
    call print_hex_word
    call print_newline

    ; -- Segment Registers --
    mov bx, MSG_SEP2
    call print_string

    mov bx, MSG_R_CS
    call print_string
    mov ax, [saved_cs]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_DS
    call print_string
    mov ax, [saved_ds]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_ES
    call print_string
    mov ax, [saved_es]
    call print_hex_word
    call print_newline

    mov bx, MSG_R_SS
    call print_string
    mov ax, [saved_ss]
    call print_hex_word
    call print_newline

    mov bx, MSG_FOOTER
    call print_string

    mov ah, 0x00
    int 0x16
    popa
    ret


; =====================================================
; VIEW 3: STACK VIEW
; =====================================================
mem_show_stack:
    pusha
    call cmd_clear

    mov bx, MSG_STK_TITLE
    call print_string

    ; Show SS value
    mov bx, MSG_STK_SS
    call print_string
    mov ax, [saved_ss]
    call print_hex_word
    call print_newline

    ; Show SP value
    mov bx, MSG_STK_SP
    call print_string
    mov ax, [saved_sp]
    call print_hex_word
    call print_newline
    call print_newline

    mov bx, MSG_STK_HDR
    call print_string

    ; Read and display 8 words from the stack
    ; We use SS:saved_sp + offset
    mov cx, 8               ; Show 8 entries
    xor dx, dx              ; Offset = 0 (bytes)

    mov bx, [saved_ss]
    mov es, bx              ; ES = saved SS

.stk_loop:
    push cx

    ; Print offset label "  SP+XX: "
    mov bx, MSG_STK_OFF
    call print_string
    mov al, dl              ; DL = byte offset
    call print_hex_byte
    mov bx, MSG_STK_SEP
    call print_string

    ; Read word at ES:[saved_sp + offset]
    mov si, [saved_sp]
    add si, dx
    mov ax, [es:si]         ; Read stack word
    call print_hex_word

    ; Mark top of stack
    cmp dx, 0
    jne .not_top
    mov bx, MSG_STK_TOP
    call print_string
.not_top:
    call print_newline

    pop cx
    add dx, 2               ; Next word (2 bytes)
    loop .stk_loop

    ; Restore ES
    xor ax, ax
    mov es, ax

    call print_newline
    mov bx, MSG_STK_NOTE
    call print_string

    mov bx, MSG_FOOTER
    call print_string

    mov ah, 0x00
    int 0x16
    popa
    ret


; =====================================================
; VIEW 4: HEX DUMP
; =====================================================
mem_hex_dump:
    pusha
    call cmd_clear

    mov bx, MSG_DUMP_TITLE
    call print_string

    ; Default address
    mov word [dump_addr], 0x7C00

.dump_loop:
    call cmd_clear

    ; Print header
    mov bx, MSG_DUMP_HDR
    call print_string

    ; Show current address
    mov bx, MSG_DUMP_AT
    call print_string
    mov ax, [dump_addr]
    call print_hex_word
    call print_newline
    call print_newline

    ; Column header
    mov bx, MSG_DUMP_COLS
    call print_string

    ; Display 8 rows x 8 bytes = 64 bytes total
    mov cx, 8               ; 8 rows
    mov si, [dump_addr]     ; Start address

.dump_row:
    push cx

    ; Print row address "0xXXXX | "
    mov ax, si
    call print_hex_word
    mov bx, MSG_DUMP_BAR
    call print_string

    ; Save SI for ASCII pass
    push si

    ; Print 8 hex bytes
    mov cx, 8
.dump_hex:
    mov al, [si]
    call print_hex_byte
    mov al, ' '
    call print_char
    inc si
    loop .dump_hex

    ; Print separator
    mov bx, MSG_DUMP_MID
    call print_string

    ; ASCII pass: print printable chars or '.'
    pop si                  ; Restore row start address
    push si
    mov cx, 8
.dump_ascii:
    mov al, [si]
    cmp al, 32              ; Below space?
    jb .dot
    cmp al, 126             ; Above tilde?
    ja .dot
    jmp .print_a
.dot:
    mov al, '.'
.print_a:
    call print_char
    inc si
    loop .dump_ascii

    pop si                  ; Restore for next row calculation
    add si, 8               ; Next row = +8 bytes

    call print_newline

    pop cx
    loop .dump_row

    ; Navigation menu
    call print_newline
    mov bx, MSG_DUMP_NAV
    call print_string

    ; Wait for key
    mov ah, 0x00
    int 0x16

    cmp al, 'n'
    je .next_page
    cmp al, 'N'
    je .next_page
    cmp al, 'p'
    je .prev_page
    cmp al, 'P'
    je .prev_page
    cmp al, 'g'
    je .goto_addr
    cmp al, 'G'
    je .goto_addr
    ; Any other key = back to menu
    jmp .dump_exit

.next_page:
    add word [dump_addr], 64
    jmp .dump_loop

.prev_page:
    sub word [dump_addr], 64
    jmp .dump_loop

.goto_addr:
    call cmd_clear
    mov bx, MSG_DUMP_GOTO
    call print_string
    call read_line

    ; Parse 4-digit hex from input_buffer
    call parse_hex_input
    mov [dump_addr], ax
    jmp .dump_loop

.dump_exit:
    popa
    ret


; Function: parse_hex_input
; Reads hex string from input_buffer, returns value in AX
parse_hex_input:
    push bx
    push cx
    push si

    xor ax, ax
    mov si, input_buffer

.parse_loop:
    mov cl, [si]
    cmp cl, 0
    je .parse_done

    shl ax, 4               ; Shift result left by 4 bits

    cmp cl, '0'
    jb .parse_done
    cmp cl, '9'
    jbe .is_digit
    cmp cl, 'A'
    jb .parse_done
    cmp cl, 'F'
    jbe .is_upper
    cmp cl, 'a'
    jb .parse_done
    cmp cl, 'f'
    ja .parse_done

    ; Lowercase a-f
    sub cl, 'a'
    add cl, 10
    jmp .add_nibble

.is_upper:
    sub cl, 'A'
    add cl, 10
    jmp .add_nibble

.is_digit:
    sub cl, '0'

.add_nibble:
    movzx bx, cl
    or ax, bx
    inc si
    jmp .parse_loop

.parse_done:
    pop si
    pop cx
    pop bx
    ret


; =====================================================
; VIEW 5: FLAGS VIEW
; =====================================================
mem_show_flags:
    pusha
    call cmd_clear

    mov bx, MSG_FLG_TITLE
    call print_string

    ; Show raw FLAGS value
    mov bx, MSG_FLG_RAW
    call print_string
    mov ax, [saved_flags]
    call print_hex_word
    call print_newline
    call print_newline

    mov bx, MSG_FLG_HDR
    call print_string

    ; Bit 0: CF (Carry Flag)
    mov bx, MSG_F_CF
    call print_string
    mov cl, 0
    call print_flag_bit
    mov bx, MSG_FC_DESC
    call print_string

    ; Bit 2: PF (Parity Flag)
    mov bx, MSG_F_PF
    call print_string
    mov cl, 2
    call print_flag_bit
    mov bx, MSG_FP_DESC
    call print_string

    ; Bit 4: AF (Auxiliary Carry)
    mov bx, MSG_F_AF
    call print_string
    mov cl, 4
    call print_flag_bit
    mov bx, MSG_FA_DESC
    call print_string

    ; Bit 6: ZF (Zero Flag)
    mov bx, MSG_F_ZF
    call print_string
    mov cl, 6
    call print_flag_bit
    mov bx, MSG_FZ_DESC
    call print_string

    ; Bit 7: SF (Sign Flag)
    mov bx, MSG_F_SF
    call print_string
    mov cl, 7
    call print_flag_bit
    mov bx, MSG_FS_DESC
    call print_string

    ; Bit 9: IF (Interrupt Enable)
    mov bx, MSG_F_IF
    call print_string
    mov cl, 9
    call print_flag_bit
    mov bx, MSG_FI_DESC
    call print_string

    ; Bit 10: DF (Direction Flag)
    mov bx, MSG_F_DF
    call print_string
    mov cl, 10
    call print_flag_bit
    mov bx, MSG_FD_DESC
    call print_string

    ; Bit 11: OF (Overflow Flag)
    mov bx, MSG_F_OF
    call print_string
    mov cl, 11
    call print_flag_bit
    mov bx, MSG_FO_DESC
    call print_string

    call print_newline
    mov bx, MSG_FOOTER
    call print_string

    mov ah, 0x00
    int 0x16
    popa
    ret

; Helper: prints '0' or '1' for flag bit CL in saved_flags
print_flag_bit:
    push ax
    push cx
    mov ax, [saved_flags]
    shr ax, cl
    and al, 1
    add al, '0'
    call print_char
    pop cx
    pop ax
    ret


; =====================================================
; VIEW 6: LIVE DEMO
; =====================================================
mem_live_demo:
    pusha
    call cmd_clear

    ; Initialize demo registers to 0
    mov word [demo_ax], 0
    mov word [demo_bx], 0
    mov byte [demo_step], 0

    mov bx, MSG_DEMO_TITLE
    call print_string
    call print_newline

    ; --- Step 1: MOV AX, 5 ---
    mov bx, MSG_D_STEP1
    call print_string
    mov word [demo_ax], 5
    call demo_show_state
    call demo_wait

    ; --- Step 2: MOV BX, 3 ---
    mov bx, MSG_D_STEP2
    call print_string
    mov word [demo_bx], 3
    call demo_show_state
    call demo_wait

    ; --- Step 3: ADD AX, BX ---
    mov bx, MSG_D_STEP3
    call print_string
    mov ax, [demo_ax]
    add ax, [demo_bx]
    mov [demo_ax], ax
    call demo_show_state
    call demo_wait

    ; --- Step 4: SUB AX, 2 ---
    mov bx, MSG_D_STEP4
    call print_string
    mov ax, [demo_ax]
    sub ax, 2
    mov [demo_ax], ax
    call demo_show_state
    call demo_wait

    ; --- Step 5: MUL BX (AX = AX * BX) ---
    mov bx, MSG_D_STEP5
    call print_string
    mov ax, [demo_ax]
    mov bx, [demo_bx]
    mul bx
    mov [demo_ax], ax
    call demo_show_state
    call demo_wait

    ; --- Step 6: MOV AX, 0 (sets ZF) ---
    mov bx, MSG_D_STEP6
    call print_string
    mov word [demo_ax], 0
    mov bx, MSG_D_ZF_SET
    call print_string
    call demo_show_state
    call demo_wait

    ; --- Done ---
    call print_newline
    mov bx, MSG_D_DONE
    call print_string

    mov ah, 0x00
    int 0x16
    popa
    ret


; Helper: Show current demo register state
demo_show_state:
    pusha
    mov bx, MSG_D_STATE
    call print_string

    mov bx, MSG_D_AX
    call print_string
    mov ax, [demo_ax]
    call print_hex_word

    mov bx, MSG_D_BX
    call print_string
    mov ax, [demo_bx]
    call print_hex_word

    call print_newline
    popa
    ret


; Helper: Wait 2 seconds between demo steps
demo_wait:
    pusha
    mov ah, 0x86
    mov cx, 0x001E          ; ~2 seconds = 2,000,000 us
    mov dx, 0x8480          ; 0x001E8480 = 2000000
    int 0x15
    popa
    ret


; =====================================================
; DATA SECTION
; =====================================================

; --- Main Menu ---
MSG_MEM_MENU:
    db '  ================================================', 13, 10
    db '  |     NanoOS Memory Visualization Tool          |', 13, 10
    db '  ================================================', 13, 10
    db '  |                                              |', 13, 10
    db '  |   [1]  Memory Map                            |', 13, 10
    db '  |   [2]  Register View                         |', 13, 10
    db '  |   [3]  Stack View                            |', 13, 10
    db '  |   [4]  Hex Dump                              |', 13, 10
    db '  |   [5]  Flags View                            |', 13, 10
    db '  |   [6]  Live Demo                             |', 13, 10
    db '  |                                              |', 13, 10
    db '  |   [Q]  Back to Shell                         |', 13, 10
    db '  |                                              |', 13, 10
    db '  ================================================', 13, 10
    db 13, 10
    db '  Select view (1-6 / Q): ', 0

MSG_FOOTER: db 13, 10, '  [Press any key to return to menu]', 0

; --- View 1: Memory Map ---
MSG_MAP:
    db '  ================================================', 13, 10
    db '  |           NanoOS System Memory Map            |', 13, 10
    db '  ================================================', 13, 10
    db '  | Address     | Size   | Contents               |', 13, 10
    db '  |-------------|--------|------------------------|', 13, 10
    db '  | 0x0000      | 1 KB   | Interrupt Vector Table |', 13, 10
    db '  | 0x0400      | 256 B  | BIOS Data Area         |', 13, 10
    db '  | 0x0500      | ~29KB  | Free Memory            |', 13, 10
    db '  | 0x7C00 >>>  | 512 B  | BOOTLOADER (boot.asm)  |', 13, 10
    db '  | 0x7E00      | 1 B    | Boot Drive Number      |', 13, 10
    db '  | 0x8000 >>>  | 64 KB  | KERNEL + Programs      |', 13, 10
    db '  | 0xB800 >>>  | 32 KB  | Video RAM (Text Mode)  |', 13, 10
    db '  | 0xC000      | 256KB  | BIOS ROM               |', 13, 10
    db '  |-------------|--------|------------------------|', 13, 10
    db '  | >>> = NanoOS regions (our code lives here!)   |', 13, 10
    db '  ================================================', 13, 10, 0
    db 13, 10
    db '  [Press any key to return to menu]', 0

; --- View 2: Registers ---
MSG_REG_TITLE: db '  === CPU Register State ===', 13, 10
               db '  (Captured at module entry)', 13, 10, 13, 10
               db '  --- General Purpose ---', 13, 10, 0
MSG_R_AX: db '  AX = 0x', 0
MSG_R_BX: db '  BX = 0x', 0
MSG_R_CX: db '  CX = 0x', 0
MSG_R_DX: db '  DX = 0x', 0
MSG_SEP1:  db 13, 10, '  --- Pointer / Index ---', 13, 10, 0
MSG_R_SP: db '  SP = 0x', 0
MSG_R_BP: db '  BP = 0x', 0
MSG_R_SI: db '  SI = 0x', 0
MSG_R_DI: db '  DI = 0x', 0
MSG_SEP2:  db 13, 10, '  --- Segment Registers ---', 13, 10, 0
MSG_R_CS: db '  CS = 0x', 0
MSG_R_DS: db '  DS = 0x', 0
MSG_R_ES: db '  ES = 0x', 0
MSG_R_SS: db '  SS = 0x', 0

; --- View 3: Stack ---
MSG_STK_TITLE: db '  === Stack Visualizer ===', 13, 10
               db '  Stack grows DOWNWARD', 13, 10, 13, 10, 0
MSG_STK_SS: db '  SS  = 0x', 0
MSG_STK_SP: db '  SP  = 0x', 0
MSG_STK_HDR: db '  -------------------------', 13, 10, 0
MSG_STK_OFF: db '  SP+', 0
MSG_STK_SEP: db ':  0x', 0
MSG_STK_TOP: db '  << TOP', 0
MSG_STK_NOTE: db '  Note: These are the actual values on the', 13, 10
              db '  hardware stack at module entry time.', 13, 10, 0

; --- View 4: Hex Dump ---
MSG_DUMP_TITLE: db '  === Memory Hex Dump ===', 13, 10, 0
MSG_DUMP_HDR: db '  === Memory Hex Dump ===', 13, 10, 0
MSG_DUMP_AT:  db '  Viewing address: 0x', 0
MSG_DUMP_COLS: db '  Address  | Hex Bytes                       | ASCII', 13, 10
               db '  ---------|---------------------------------|--------', 13, 10, 0
MSG_DUMP_BAR: db ' | ', 0
MSG_DUMP_MID: db '| ', 0
MSG_DUMP_NAV: db '  [N] Next  [P] Prev  [G] Go to address  [Any] Back', 13, 10, 0
MSG_DUMP_GOTO: db '  Enter hex address (e.g. 7C00): ', 0

; --- View 5: Flags ---
MSG_FLG_TITLE: db '  === CPU Flags Register ===', 13, 10, 13, 10, 0
MSG_FLG_RAW: db '  FLAGS = 0x', 0
MSG_FLG_HDR: db '  Bit | Flag                  | Val | Meaning', 13, 10
             db '  ----|------------------------|-----|------------------', 13, 10, 0
MSG_F_CF: db '   0  | CF - Carry Flag        |  ', 0
MSG_F_PF: db '   2  | PF - Parity Flag       |  ', 0
MSG_F_AF: db '   4  | AF - Auxiliary Carry    |  ', 0
MSG_F_ZF: db '   6  | ZF - Zero Flag         |  ', 0
MSG_F_SF: db '   7  | SF - Sign Flag         |  ', 0
MSG_F_IF: db '   9  | IF - Interrupt Enable   |  ', 0
MSG_F_DF: db '  10  | DF - Direction Flag     |  ', 0
MSG_F_OF: db '  11  | OF - Overflow Flag      |  ', 0
MSG_FC_DESC: db '  | Math carry/borrow', 13, 10, 0
MSG_FP_DESC: db '  | Even parity in result', 13, 10, 0
MSG_FA_DESC: db '  | BCD half-carry', 13, 10, 0
MSG_FZ_DESC: db '  | Result was zero', 13, 10, 0
MSG_FS_DESC: db '  | Result was negative', 13, 10, 0
MSG_FI_DESC: db '  | Hardware IRQs on', 13, 10, 0
MSG_FD_DESC: db '  | String direction', 13, 10, 0
MSG_FO_DESC: db '  | Signed overflow', 13, 10, 0

; --- View 6: Live Demo ---
MSG_DEMO_TITLE: db '  === Live Register Demo ===', 13, 10
                db '  Watch how instructions change registers!', 13, 10, 0
MSG_D_STEP1: db 13, 10, '  > MOV AX, 5      (Load 5 into AX)', 13, 10, 0
MSG_D_STEP2: db 13, 10, '  > MOV BX, 3      (Load 3 into BX)', 13, 10, 0
MSG_D_STEP3: db 13, 10, '  > ADD AX, BX     (AX = AX + BX)', 13, 10, 0
MSG_D_STEP4: db 13, 10, '  > SUB AX, 2      (AX = AX - 2)', 13, 10, 0
MSG_D_STEP5: db 13, 10, '  > MUL BX         (AX = AX * BX)', 13, 10, 0
MSG_D_STEP6: db 13, 10, '  > MOV AX, 0      (Clear AX)', 13, 10, 0
MSG_D_ZF_SET: db '    ** Zero Flag (ZF) is now SET! **', 13, 10, 0
MSG_D_DONE:   db '  Demo complete!', 13, 10
              db '  [Press any key to return to menu]', 0
MSG_D_STATE: db '    State: ', 0
MSG_D_AX:    db 'AX=0x', 0
MSG_D_BX:    db '  BX=0x', 0

; --- Saved Register Storage ---
saved_ax:    dw 0
saved_bx:    dw 0
saved_cx:    dw 0
saved_dx:    dw 0
saved_si:    dw 0
saved_di:    dw 0
saved_sp:    dw 0
saved_bp:    dw 0
saved_cs:    dw 0
saved_ds:    dw 0
saved_es:    dw 0
saved_ss:    dw 0
saved_flags: dw 0

; --- Hex Dump State ---
dump_addr:   dw 0x7C00

; --- Demo State ---
demo_ax:     dw 0
demo_bx:     dw 0
demo_step:   db 0
