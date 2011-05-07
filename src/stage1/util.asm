; Stage1 debug utils
; asmsyntax=nasm

bits 16

videomem equ 0xb800
cols equ 80
rows equ 25

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
    mul ch
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
    mov word [cursor], 0
.ret:
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
    pop di
    pop es
    ret


section .data
cursor: dw 0
