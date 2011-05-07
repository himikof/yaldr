; Stage2 code
; asmsyntax=nasm

%include "asm/stage2_common.inc"

bits 16
section .text.head

; Will be at 0x8000
global stage2_start
stage2_start:

    ; There is current disk number in DL

    call clear_screen

    push test_msg
    call print

    jmp $

    call switch_to_unreal

    jmp $

section .data
    boot_disk_id: db 0
    test_msg: db 'We are here!', 10, 0

