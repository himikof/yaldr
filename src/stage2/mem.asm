; Memory detection (not tested yet)
; asmsyntax=nasm

%include "asm/stage2_common.inc"

BITS 16

; Segment 0x1000 (64 KB) is internal allocator memory


section .text

global detect_memory
detect_memory:
    push ds
    push es
    mov ax,0x1000
    mov ds,ax
    mov es,ax
    xor ebx,ebx
    mov di,0

    .get:
        mov [es:di+20],dword 1  ; pre-ACPI 3.0 compatibility
        mov edx,0x534D4150
        mov ecx,24
        mov eax,0xE820
        int 0x15
        cmp eax,0x534D4150
        jne .get.end
        jc .get.end

        ; if length==0: skip
        mov ecx,[es:di+8]
        or ecx,[es:di+12]
        jz .get.next

        ; if ACPI.noignore==0: skip
        mov ecx,[es:di+20]
        and ecx,1
        jz .get.next

        add di,24

    .get.next:
        test ebx,ebx
        jz .get.end
        jmp .get
    .get.end:

    and edi,0xFFFF
    jz error_got_nothing

    ; Gnome sort
    mov si,24
    mov bx,24+24
    .sort:
        cmp si,di
        jae .sort.end

        mov ecx,[es:si+4]   ;- if a[i] < a[i-1]: swap
        mov edx,[es:si-20]  ;|
        cmp ecx,edx         ;|
        jb .sort.swap       ;|
        mov ecx,[es:si]     ;|
        mov edx,[es:si-24]  ;|
        jb .sort.swap       ;/
        jmp .sort.forward
    .sort.swap:
        %assign i 0
        %rep 6
            mov ecx,[es:si+0+i*4]
            mov edx,[es:si-24+i*4]
            mov [es:si+0+i*4],edx
            mov [es:si-24+i*4],ecx
            %assign i i+1
        %endrep
        sub si,24
        jnz .sort   ;- if i==0: i, j = j, j+1
    .sort.forward:  ;|
        mov si,bx   ;|
        add bx,24   ;/
        jmp .sort
    .sort.end:

    jmp done


error_got_nothing:
    push error_msg
    call print
    add sp, 2
    jmp done


done:
    mov cx,di
    mov si,di
    dec si
    mov di,0xFFFF
    std
    rep movsb
    cld
    xor eax,eax
    mov ax,di
    add eax,1
    mov ebx,eax
    and ebx,0xFFFF0000
    clc
    jz exit
    stc
exit:
    pop es
    pop ds
    ret

section .data
    error_msg: db 'Unable to detect memory', 10, 0
