; Memory detection (not tested yet)
; asmsyntax=nasm

%include "asm/output.inc"

BITS 16

; Segment 0x1000 (64 KB) is internal allocator memory
; Map:
;       
;       0x1dfff-0x1ffff - memory map (8 KB)

section .text

; Detects available memory, fills memory map table.
; No arguments.
; Returns a pointer to memory map start. Memory map end is at MEMORY_MAP_END.
; CF is set in case of failure (empty memort map).
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
        mov [di],dword 24
        add di,4
        mov [es:di+20],dword 1  ; pre-ACPI 3.0 compatibility
        mov edx,0x534D4150
        mov ecx,24
        mov eax,0xE820
        int 0x15
        sub di,4
        cmp eax,0x534D4150
        jne .get.end
        jc .get.end

        ; if length==0: skip
        mov ecx,[es:di+8+4]
        or ecx,[es:di+12+4]
        jz .get.next

        ; if ACPI.noignore==0: skip
        mov ecx,[es:di+20+4]
        and ecx,1
        jz .get.next

        add di,24+4

    .get.next:
        test ebx,ebx
        jz .get.end
        jmp .get
    .get.end:

    and edi,0xFFFF
    jz .error_got_nothing

    ; Gnome sort
    mov si,28
    mov bx,28+28
    .sort:
        cmp si,di
        jae .sort.end

        mov ecx,[es:si+8]   ;- if a[i] < a[i-1]: swap
        mov edx,[es:si-20]  ;|
        cmp ecx,edx         ;|
        jb .sort.swap       ;|
        mov ecx,[es:si+4]   ;|
        mov edx,[es:si-24]  ;|
        jb .sort.swap       ;/
        jmp .sort.forward
    .sort.swap:
        %assign i 0
        %rep 7
            mov ecx,[es:si+0+i*4]
            mov edx,[es:si-28+i*4]
            mov [es:si+0+i*4],edx
            mov [es:si-28+i*4],ecx
            %assign i i+1
        %endrep
        sub si,28
        jnz .sort   ;- if i==0: i, j = j, j+1
    .sort.forward:  ;|
        mov si,bx   ;|
        add bx,28   ;/
        jmp .sort
    .sort.end:

    jmp .done


.error_got_nothing:
    push error_msg
    call print
    add sp, 2
    jmp .done


.done:
    mov cx,di
    mov si,di
    dec si
    mov di,0xFFFF
    std
    rep movsb
    cld
    xor eax,eax
    mov ds,ax
    mov ax,di
    add eax,1
    mov ebx,eax
    add eax,0x10000
    stc
    and ebx,0xFFFF0000
    jnz exit
    clc
    mov [ds:mem_map_start],eax
exit:
    pop es
    pop ds
    ret

section .data
    global mem_map_start
    mem_map_start: dd 0
    error_msg: db 'Unable to detect memory', 10, 0
