; Stage2 code
; asmsyntax=nasm

%include "asm/a20.inc"
%include "asm/cpumode.inc"
%include "asm/mem.inc"
%include "asm/output.inc"

BITS 16

section .text.head

; Will be at 0x8000, max size 256 bytes
global stage2_start
stage2_start:

    ; There is current disk number in DL

    call a20_ensure
    test eax,eax
    jnz .a20_ok
    push a20_failed_msg
    call print
    call loader_panic
.a20_ok:

    call switch_to_unreal

    call clear_screen

    call detect_memory

    push exec_msg
    call print
    mov esi,20
    call sleep
    push exec_msg2
    call print
    mov esi,20
    call sleep

    ; Time to load kernel!

    jmp $

section .data.head

; Will be at 0x8100, max size 256 bytes
; TO BE PATCHED IN
; An array of stage2 32-bit LBAs (except the first), maximum 32
stage2_blocks:
    times 32 db 0xDE, 0xAD, 0xBE, 0xEF

section .text

global loader_panic
loader_panic:
    push panic_msg
    call print
    add sp, 2
    jmp $


; Takes number of ticks in esi
global sleep
sleep:
    xor ah,ah
    int 1Ah
    shl ecx,16
    mov cx,dx
    mov edi,ecx
    .loop:
        xor ah,ah
        int 1Ah
        shl ecx,16
        mov cx,dx
        mov ebx,ecx
        test al,al
        jz .loop.midnightok
        add ecx,1800B0h     ; 24 hours
    .loop.midnightok:
        sub ecx,edi
        cmp ecx,esi
        ja .loop.end
        sub esi,ecx
        mov edi,ebx
        jmp .loop
    .loop.end:
    ret


section .data
    boot_disk_id: db 0

    a20_failed_msg: db 'Could not enable A20', 10, 0
    exec_msg: db 'I have a surprise for you! Deploying surprise in 5...', 0
    exec_msg2: db '4...', 10, 0
    panic_msg: db 'Loader panic, stopping here', 10, 0
