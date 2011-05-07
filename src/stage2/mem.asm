; Memory detection (not tested yet)
; asmsyntax=nasm

BITS 16

; Segment 0x1000 (64 KB) is internal allocator memory


global detect_memory

section .text
detect_memory:
    xor ebx,ebx
    mov di,memtable

    .get:
        mov [es:di+20],dword 1
        mov edx,0x534D4150
        mov ecx,24
        mov eax,0xE820
        int 0x15
        cmp eax,0x534D4150
        jne .get.end
        jc .get.end

        ;if length==0: skip
        mov ecx,[es:di+8]
        or ecx,[es:di+12]
        jz .get.next

        ;if ACPI.noignore==0: skip
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
    mov esi,memtable
    cmp esi,edi
    je error_got_nothing

    ;Gnome sort
    mov eax,esi
    add eax,24
    mov ebx,eax
    add ebx,24
    .sort:
        cmp eax,edi
        jae .sort.end

        mov ecx,[es:eax+4]  ;- if a[i] < a[i-1]: swap
        mov edx,[es:eax-20] ;|
        cmp ecx,edx         ;|
        jb .sort.swap       ;|
        mov ecx,[es:eax]    ;|
        mov edx,[es:eax-24] ;|
        jb .sort.swap       ;/
        jmp .sort.forward
    .sort.swap:
        %assign i 0
        %rep 6
            mov ecx,[es:eax+0+i*4]
            mov edx,[es:eax-24+i*4]
            mov [es:eax+0+i*4],edx
            mov [es:eax-24+i*4],ecx
            %assign i i+1
        %endrep
        sub eax,24
        cmp eax,esi ;- if i==0: i, j = j, j+1
        jne .sort   ;|
    .sort.forward:  ;|
        mov eax,ebx ;|
        add ebx,24  ;/
        jmp .sort
    .sort.end:


    jmp done


error_got_nothing:
    mov al,'('
    mov ah,0x0E
    int 0x10
    jmp done


done:
    mov eax,memtable
    ret

section .data
    memtable: times 128*3 dq 0

