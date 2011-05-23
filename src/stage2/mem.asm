; Memory detection
; asmsyntax=nasm

%include "asm/output.inc"

BITS 16

; Segment 0x1000 (64 KB) is internal allocator memory
; Map:
;       0x10000-0x101ff - Global mspace_t (512 B)
;       
;       0x1dfff-0x1ffff - memory map (8 KB)

GLOBAL_MSPACE equ 0x10000

struc mem_map_t
    .entry_size: resd 1 ; size of this structure
    .base: resq 1       ; memory region base address
    .length: resq 1     ; memory region length
    .type: resd 1       ; memory region type
    .extended: resd 1   ; memory region extended attributes
endstruc

; Memory chunk
struc mchunk_t
    .prev_size: resd 1  ; size of the previous chunk,
                        ;   used only if previous chunk is free
    .size: resd 1       ; size of this chunk, except for two lowest bits
                        ;   bit 1: 1 if this chunk is used
                        ;   bit 0: 1 if previous chunk is used
    .data:              ; start of chunk data
    .next: resd 1       ; pointer to the next chunk in the list
                        ;   used only if this chunk is free
    .prev: resd 1       ; pointer to the previous chunk in the list
                        ;   used only if this chunk is free                        
endstruc

; Large free memory chunk
struc trie_mchunk_t
    .prev_size: resd 1  ; size of the previous chunk,
                        ;   used only if previous chunk is free
    .size: resd 1       ; size of this chunk, except for two lowest bits
                        ;   bit 1: 1 if this chunk is used
                        ;   bit 0: 1 if previous chunk is used
    .data:              ; start of chunk data
    .next: resd 1       ; pointer to the next chunk in the list
                        ;   used only if this chunk is free
    .prev: resd 1       ; pointer to the previous chunk in the list
                        ;   used only if this chunk is free
    .left: resd 1       ; pointer to the left child trie_mchunk_t
    .right: resd 1      ; pointer to the right child trie_mchunk_t
    .parent: resd 1     ; pointer to the parent trie_mchunk_t
endstruc

BIT_PINUSE equ 1
BIT_INUSE equ 2

; Memory space
struc mspace_t
    .smallbins: resd 66 ; the small bins (only list pointers)
    .treebins: resd 24  ; the tree bins
    .smallmap: resd 1   ; the small bins' bitmap
    .treemap: resd 1    ; the tree bins' bitmap
    .dv: resd 1         ; the "designated victim" chunk
    .dvsize: resd 1     ; the "designated victim" chunk size
endstruc

; There are 32 "small" bins for sizes 8, 16, ... 248
; Also there is 24 tries of "large" bins for larger sizes

ALIGNMENT equ 8
CHUNK_ALIGN_MASK equ ALIGNMENT - 1
CHUNK_OVERHEAD equ 4
CHUNK_MEM_OFFSET equ 8
MIN_REQUEST equ mchunk_t_size - CHUNK_OVERHEAD
MAX_REQUEST equ -mchunk_t_size << 2
SMALL_SHIFT equ 3
LARGE_SHIFT equ 8
MIN_LARGE_SIZE equ 1 << LARGE_SHIFT
MAX_SMALL_SIZE equ MIN_LARGE_SIZE - 1
MAX_SMALL_REQUEST equ MAX_SMALL_SIZE - CHUNK_ALIGN_MASK - CHUNK_OVERHEAD

%macro chunk2mem 1
    lea eax, [%1 + CHUNK_MEM_OFFSET]
%endmacro

%macro mem2chunk 1
    lea eax, [%1 - CHUNK_MEM_OFFSET]
%endmacro

%macro smallbin_at 1
    lea eax, [GLOBAL_MSPACE + mspace_t.smallbins + 2 * %1]
%endmacro

; set_inuse(chunk, size)
%macro set_inuse 2
    mov eax, [dword %1 + mchunk_t.size]
    and eax, BIT_PINUSE
    or eax, %2
    or eax, BIT_INUSE
    mov [dword %1 + mchunk_t.size], eax
    or dword [dword %1 + %2 + mchunk_t.size], BIT_PINUSE
%endmacro

; set_inuse_pinuse(chunk, size)
%macro set_inuse_pinuse 2
    mov eax, %2
    or eax, BIT_INUSE | BIT_PINUSE
    mov [dword %1 + mchunk_t.size], eax
    or dword [dword %1 + %2 + mchunk_t.size], BIT_PINUSE
%endmacro

; set_free_pinuse_size(chunk, size)
%macro set_free_pinuse_size 2
    mov eax, %2
    or eax, BIT_PINUSE
    mov [dword %1 + mchunk_t.size], eax
    mov [dword %1 + %2 + mchunk_t.prev_size], %2
%endmacro

; insert_small(this, size)
%macro insert_small 2
    %push local
    push esi
    push edi
    mov esi, %2
    shr esi, SMALL_SHIFT
    smallbin_at esi
    mov edi, eax
    bt dword [dword GLOBAL_MSPACE + mspace_t.smallmap], esi
    jnc %$else
        mov edi, dword [eax + mchunk_t.next]
        jmp %$endif
    %$else:
        bts dword [dword GLOBAL_MSPACE + mspace_t.smallmap], esi
    %$endif:
    ; eax == prev, edi == next
    mov dword [eax + mchunk_t.next], %1
    mov dword [edi + mchunk_t.prev], %1
    mov dword [dword %1 + mchunk_t.next], edi
    mov dword [dword %1 + mchunk_t.prev], eax
    pop edi
    pop esi
    %pop
%endmacro

; unlink_first_small(prev, this, index)
%macro unlink_first_small 3
    %push local
    mov eax, [%2 + mchunk_t.next]
    cmp eax, %1
    jne %$else
        btc [dword GLOBAL_MSPACE + mspace_t.smallmap], %3
        jmp %$endif
    %$else:
        mov dword [dword %1 + mchunk_t.next], ebx
        mov dword [dword eax + mchunk_t.prev], %1
    %$endif:
    %pop
%endmacro

section .text

; Initializes the allocator.
; No arguments.
; Returns 0 in case of success.
; Precondition: detect_memory is called.
global init_alloc
init_alloc:
    mov edx, [mem_map_start]
    test edx, edx
    jnz .l1
        mov eax, 1
        jmp .epilogue
    .l1:
    
    xor eax, eax
.epilogue:
    ret

; update_dv(this, size)
update_dv:
    mov eax, [dword GLOBAL_MSPACE + mspace_t.dvsize]
    test eax, eax
    jz .endif
        ; assert(eax <= MAX_SMALL_SIZE)
        mov edx, [dword GLOBAL_MSPACE + mspace_t.dv]
        mov ecx, eax
        insert_small edx, ecx
    .endif:
    mov eax, [esp + 4]
    mov [dword GLOBAL_MSPACE + mspace_t.dv], eax
    mov eax, [esp + 8]
    mov [dword GLOBAL_MSPACE + mspace_t.dvsize], eax
    ret 8


; Main memory allocation routine.
; Argument: dword size - size of memory to be allocated.
; Return value: pointer in case of success, 0 in case of failure.
; Precondition: init_alloc is called.
global malloc
malloc:
    push ebp
    mov ebp, esp
    sub esp, 8
%define size ebp - 8
%define nb esp + 4 ; real allocation size, 4 bytes
%define mem esp    ; allocated memory pointer, 4 bytes 
    mov dword [mem], 0
    mov edx, [size]
    cmp edx, MAX_SMALL_REQUEST
    ja .large_request
    ; Small requests
    ; Pad size to ALIGNMENT
    mov eax, edx
    add ax, CHUNK_OVERHEAD + CHUNK_ALIGN_MASK
    and ax, ~CHUNK_ALIGN_MASK
    cmp dx, MIN_REQUEST
    mov ecx, mchunk_t_size
    cmovb eax, ecx
    mov dword [nb], eax
    mov ecx, eax
    shr cx, SMALL_SHIFT  ; now cl == small bin index
    mov eax, [dword GLOBAL_MSPACE + mspace_t.smallmap]
    shr eax, cl
    test eax, 0x03
    jz .no_smallfit
        ; Got a small bin "exact" fit
        bt eax, 1
        cmc
        adc cl, 0   ; use the next bin if cl one is empty
        smallbin_at ecx
        mov edx, eax
        mov ebx, [eax + mchunk_t.next]
        ; Unlink the chunk
        unlink_first_small edx, ebx, ecx
        mov edx, ecx
        shl edx, SMALL_SHIFT
        set_inuse_pinuse ebx, edx
        chunk2mem ebx
        mov dword [mem], eax
        ; Success
        jmp .epilogue
    .no_smallfit:
    mov ebx, dword [nb]
    cmp ebx, [dword GLOBAL_MSPACE + mspace_t.dvsize]
    ; Exit way
    jbe .check_dv
        ; Search for a small chunk
        ; eax == shifted small bin mask
        test eax, eax
        jz .tree_small
            ; Chunks available
            bsf ebx, eax
            add bx, cx
            mov ecx, ebx
            ; ecx == bin index
            smallbin_at ecx
            mov edx, eax
            mov ebx, [eax + mchunk_t.next]
            ; Unlink the chunk
            unlink_first_small edx, ebx, ecx
            mov eax, ecx
            shl eax, SMALL_SHIFT
            mov edx, dword [nb]
            sub eax, edx
            ; eax == remaining size
            push eax
            set_inuse_pinuse ebx, edx
            pop eax
            mov ecx, ebx
            add ecx, edx
            mov edx, eax
            ; ecx == new free chunk start, edx == its length
            set_free_pinuse_size ecx, edx
            ; Update the dv
            push edx
            push ecx
            call update_dv
            chunk2mem ebx
            mov dword [mem], eax
            ; Success
            jmp .epilogue
        .tree_small:
            ; Try to serve small request from the tree
                ; Exit way
                jmp .check_dv
            jmp .epilogue
        jmp .epilogue
.large_request:
    cmp edx, MAX_REQUEST
    jbe .tree_large
        ; Too big request
        jmp .epilogue
.tree_large:
    ; Try to serve large request from the tree
    ; Pad size to ALIGNMENT
    mov eax, edx
    add ax, CHUNK_OVERHEAD + CHUNK_ALIGN_MASK
    and ax, ~CHUNK_ALIGN_MASK
    mov dword [nb], eax    

    nop
    
.check_dv:
    mov eax, dword [nb]
    mov ecx, [dword GLOBAL_MSPACE + mspace_t.dvsize]
    cmp eax, ecx
    ja .no_more_options
        sub ecx, eax
        ; ecx == remaining size
        mov ebx, [dword GLOBAL_MSPACE + mspace_t.dv]
        cmp ecx, mchunk_t_size
        jb .exhaust_dv
            ; Split dv
            mov edx, eax
            set_inuse_pinuse ebx, edx
            lea edx, [ebx + edx]
            set_free_pinuse_size edx, ecx
            mov [dword GLOBAL_MSPACE + mspace_t.dvsize], ecx
            mov [dword GLOBAL_MSPACE + mspace_t.dv], ebx
            jmp .dv_handled
        .exhaust_dv:
            mov edx, eax
            set_inuse_pinuse ebx, edx
            xor eax, eax
            mov [dword GLOBAL_MSPACE + mspace_t.dvsize], eax
            mov [dword GLOBAL_MSPACE + mspace_t.dv], eax
        .dv_handled:
        chunk2mem ebx
        mov dword [mem], eax
        ; Success
        jmp .epilogue
.no_more_options:
.epilogue:
    pop ebp
    ret

; Main memory deallocation routine.
; Argument: pointer returned by malloc.
; No return value.

global free
free:
    ret

; Detects available memory, fills memory map table.
; No arguments.
; Returns a pointer to memory map start. Memory map end is at MEMORY_MAP_END.
; CF is set in case of failure (empty memort map).
global detect_memory
detect_memory:
    record_size equ 28
    push ds
    push es
    mov ax,0x1000
    mov ds,ax
    mov es,ax
    xor ebx,ebx
    mov di,0

    .get:
        mov [di],dword record_size-4
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

        add di,record_size

    .get.next:
        test ebx,ebx
        jz .get.end
        cmp di,record_size*128  ;- just read 128-th record, ignore remaining
        jae .get.end            ;/

        jmp .get

    .get.end:

    and edi,0xFFFF
    jz .error_got_nothing

    ; Gnome sort
    mov si,record_size
    mov bx,record_size+record_size
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
        %rep record_size/4
            mov ecx,[es:si+0+i*4]
            mov edx,[es:si-record_size+i*4]
            mov [es:si+0+i*4],edx
            mov [es:si-record_size+i*4],ecx
            %assign i i+1
        %endrep
        sub si,record_size
        jnz .sort           ;- if i==0: i, j = j, j+1
    .sort.forward:          ;|
        mov si,bx           ;|
        add bx,record_size  ;/
        jmp .sort
    .sort.end:

    jmp .done


.error_got_nothing:
    push error_msg
    call print
    add sp,2
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
    jnz .exit
    clc
    mov [ds:mem_map_start],eax
.exit:
    pop es
    pop ds
    ret

section .data
    global mem_map_start
    mem_map_start: dd 0
    error_msg: db 'Unable to detect memory', 10, 0
