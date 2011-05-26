; Memory detection
; asmsyntax=nasm

%include "asm/mem_private.inc"
%include "asm/output.inc"
%include "asm/main.inc"

BITS 16

; Segment 0x1000 (64 KB) is internal allocator memory
; Map:
;       0x10000-0x101ff - Global mspace_t (512 B)
;       
;       0x1dfff-0x1ffff - memory map (8 KB)

GLOBAL_MSPACE equ 0x10000

%ifdef MALLOC_PREFIX
%define %[MALLOC_PREFIX]malloc malloc
%define %[MALLOC_PREFIX]free free
%define %[MALLOC_PREFIX]init_alloc init_alloc
%endif

struc mem_map_t
    .entry_size: resd 1 ; size of this structure
    .base: resq 1       ; memory region base address
    .length: resq 1     ; memory region length
    .type: resd 1       ; memory region type (1 is RAM)
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

%macro treebin_at 1
    lea eax, [GLOBAL_MSPACE + mspace_t.treebins + %1]
%endmacro

%macro get_tree_index 1
    %push local
    push esi
    mov esi, %1
    xor eax, eax
    shr esi, LARGE_SHIFT
    jz %$end
    cmp esi, 0xFFFF
    jbe %$else
        mov eax, 31
        jmp %$end
    %$else:
        bsr eax, esi
        push eax
        mov esi, %1
        add eax, LARGE_SHIFT - 1
        bt esi, eax
        setc al
        cbw
        mov si, ax
        pop eax
        shl eax, 1
        add ax, si
    %$end:
    pop esi
    %pop
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

global init_alloc
global malloc
global free

; Initializes the allocator.
; No arguments.
; Returns 0 in case of success.
; Precondition: detect_memory is called.
dl_init_alloc:
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

; Allocate large request from the tree.
; Argument: dword size - aligned size of memory to be allocated.
; Return value: pointer in case of success, 0 in case of failure.
treemalloc_large:
%define FRAME_SIZE 16
    sub esp, FRAME_SIZE
%define size esp + FRAME_SIZE + 8
%define rsize esp + 12    ; 4 bytes
%define target esp + 8    ; 4 bytes
%define node esp + 4      ; 4 bytes
%define right_subtree esp ; 4 bytes
    mov ecx, [size]  ; the size
    mov ebx, ecx
    not ebx
    mov [rsize], ebx
    get_tree_index ecx
    mov ebx, eax
    treebin_at ebx
    test eax, eax
    jz .next_nonempty_bin
    
    
.next_nonempty_bin:

    add esp, FRAME_SIZE
    ret 

; Main memory allocation routine.
; Argument: dword size - size of memory to be allocated.
; Return value: pointer in case of success, 0 in case of failure.
; Precondition: init_alloc is called.
dl_malloc:
    push ebp
    mov ebp, esp
    sub esp, 8
%define size ebp + 8
%define nb ebp - 4  ; real allocation size, 4 bytes
%define mem ebp - 8 ; allocated memory pointer, 4 bytes
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
dl_free:
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
    printline 'Unable to detect memory', 10
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

; Main memory allocation routine.
; Argument: dword size - size of memory to be allocated.
; Return value: pointer in case of success, 0 in case of failure.
; Precondition: init_alloc is called.
test_malloc:
    push bp
    mov bp, sp
%define size bp + 4  ; 4 bytes
    mov ecx, [test_mem_free]
    add ecx, dword [size]
    jo .failure
    cmp ecx, [test_mem_end]
    jae .failure
    mov eax, [test_mem_free]
    mov [test_mem_free], ecx
    jmp .epilogue
.failure:
%ifdef MALLOC_PANIC
    printline "Allocator memory exhausted!", 10
    call loader_panic
%endif
    xor eax, eax
.epilogue:
    pop bp
    ret

; Main memory deallocation routine. A noop in this implementation.
; Argument: pointer returned by malloc.
; No return value.
test_free:
    ret

; Initializes the allocator.
; No arguments.
; Returns 0 in case of success.
; Precondition: detect_memory is called.
test_init_alloc:
    push esi
    mov edx, [mem_map_start]
    test edx, edx
    jnz .l1
        mov eax, 1
        jmp .epilogue
    .l1:
%ifdef MALLOC_HIGH
    xor esi, esi  ; High dword
    xor ecx, ecx  ; Low dword
    ; ebx == max entry
    xor ebx, ebx
    .map_loop:
        cmp edx, MEMORY_MAP_END
        jae .end
        cmp dword [edx + mem_map_t.type], 1
        jne .continue
        cmp dword [edx + mem_map_t.base + 4], 0
        jne .continue
        cmp dword [edx + mem_map_t.base], 0x100000
        jb .continue
        cmp dword [edx + mem_map_t.length + 4], esi
        ja .size_a
        jb .size_be
        cmp dword [edx + mem_map_t.length], ecx
        ja .size_a
        .size_be:
            jmp .continue
        .size_a:
            mov esi, dword [edx + mem_map_t.length + 4]
            mov ecx, dword [edx + mem_map_t.length]
            mov ebx, edx
    .continue:
        add edx, dword [edx + mem_map_t.entry_size]
        add edx, 4
        jmp .map_loop
.end:
    test ebx, ebx
    jnz .got_memory
    mov eax, 2
    jmp .epilogue
.got_memory:
    mov eax, dword [ebx + mem_map_t.base]
    mov dword [test_mem_base], eax
    mov dword [test_mem_free], eax
    xor edx, edx
    not edx
    add eax, ecx
    cmovo eax, edx
    mov dword [test_mem_end], eax
%elifdef MALLOC_LOW
    ; Use 0x30000-0x50000 (128 KB)
    mov eax, 0x30000
    mov dword [test_mem_base], eax
    mov dword [test_mem_free], eax
    mov dword [test_mem_end], 0x50000
%else
    %error No malloc policy defined
%endif
.success:
    xor eax, eax
.epilogue:
    pop esi
    ret

; memcpy(dest, src, size)
; Memory copying. No buffer overlap is permitted.
; Argument: dest - pointer to destination
; Argument: src - pointer to source
; Argument: size - dword, number of bytes to copy
; Return value: dest
global memcpy
memcpy:
    push edi
    push esi
    mov edi, [esp + 10]
    mov esi, [esp + 14]
    mov ecx, [esp + 18]
    mov edx, ecx
    shr ecx, 2
    jz .l2
    .l1:
        mov eax, [esi]
        mov [edi], eax
        add esi, 4
        add edi, 4
        dec ecx
        jnz .l1
    .l2:
    mov ecx, edx
    and ecx, 0x03
    jz .l4
    .l3:
        mov al, [esi]
        mov [edi], al
        inc esi
        inc edi
        dec ecx
        jnz .l3
    .l4:
.epilogue:
    pop esi
    pop edi
    ret


section .data
    global mem_map_start
    mem_map_start: dd 0
    test_mem_base: dd 0
    test_mem_free: dd 0
    test_mem_end: dd 0
