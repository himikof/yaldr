; Stage2 output code
; asmsyntax=nasm


bits 16

videomem equ 0xb800
cols equ 80
rows equ 25
port_crt_index equ 0x03d4
port_crt_data equ 0x03d5
cursor_loc_low equ 0x0f
cursor_loc_high equ 0x0e

section .text
global print
print:
    push si
    mov si, [esp + 4]
    xor ax, ax
.repeat:
    lodsb
    test al, al
    jz .end
    push ax
    call putc
    add sp, 2
    jmp .repeat
.end
    pop si
    ret

global putc
putc:
    mov cl, [esp + 2]
    cmp cl, 10
    jne .simple
    mov ch, cols
    mov ax, [cursor]
    xor edx, edx
    div ch
    inc ax
    mul bh
    mov [cursor], ax
    jmp .end
.simple:
    mov ch, 0x07 ; attributes
    push es
    mov ax, videomem
    mov es, ax
    movzx eax, word [cursor]
    mov word [es:2*eax], cx
    inc ax
    mov [cursor], ax
    pop es
.end:
    cmp word [cursor], cols * rows - 1
    jne .ret
    ; TODO: implement scroll down
    mov word [cursor], 0
.ret:
    call sync_cursor
    ret

global clear_screen
clear_screen:
    push es
    mov ax, videomem
    mov es, ax
    push di
    xor di, di
    mov cx, cols * rows
    mov ax, 0x0720
    rep stosw
    mov word [cursor], 0
    call sync_cursor
    pop di
    pop es
    ret

sync_cursor:
    mov bx, [cursor]
    
    mov al, cursor_loc_low
    mov dx, port_crt_index
    out dx, al

    mov al, bl
    mov dx, port_crt_data
    out dx, al

    mov al, cursor_loc_high
    mov dx, port_crt_index
    out dx, al

    mov al, bh
    mov dx, port_crt_data
    out dx, al

    ret

section .data
cursor: dw 0
