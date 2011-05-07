; A20 (not tested yet)
; asmsyntax=nasm

BITS 16

global a20_test
global a20_ensure

section .text
a20_test:
    push es

    mov ax,0xFFFF
    mov es,ax
    mov si,0x500
    mov di,0x510
    mov bl,[ds:si]
    mov bh,[es:di]
    mov byte [ds:si],0x01
    mov byte [es:di],0x00
    xor eax,eax
    mov al,[ds:si]
.end:
    mov [ds:si],bl
    mov [es:di],bh
    pop es
    ret

a20_ensure:
    call a20_test
    test eax,eax
    jnz .end

    ;try BIOS
    mov ax,0x2401
    int 0x15

    call a20_test
    test eax,eax
    jnz .end

    ;try keyboard controller
    cli
    call .kbcwaitready
    mov al,0xAD     ;disable keyboard
    out 0x64,al
    call .kbcwaitready
    mov al,0xD0     ;read output port
    out 0x64,al
    call .kbcwaitinput
    in al,0x60
    mov cl,al
    call .kbcwaitready
    mov al,0xD1     ;write output port
    out 0x64,al
    call .kbcwaitready
    mov al,cl
    or al,2         ;set A20 enabled
    out 0x60,al
    call .kbcwaitready
    mov al,0xAE     ;enable keyboard
    out 0x64,al
    call .kbcwaitready
    sti

    call a20_test
.end:
    ret

.kbcwaitready:
    in al,0x64
    test al,2
    jnz .kbcwaitready
    ret
.kbcwaitinput:
    in al,0x64
    test al,1
    jz .kbcwaitinput
    ret
