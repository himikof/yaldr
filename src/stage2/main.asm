; Stage2 code
; asmsyntax=nasm

%include "asm/stage2_common.inc"

BITS 16

section .text.head

; Will be at 0x8000
global stage2_start
stage2_start:

    ; There is current disk number in DL

    call switch_to_unreal

    call clear_screen

    push test_msg
    call print

    ;call detect_memory
    
    jmp $

section .text

global loader_panic
loader_panic:
    push panic_msg
    call print
    add sp, 2
    jmp $

section .data
    boot_disk_id: db 0
    test_msg: db 'We are here!', 10, 0
    panic_msg: db 'Loader panic, stopping here', 10, 0
