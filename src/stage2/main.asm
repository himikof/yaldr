; Stage2 code
; asmsyntax=nasm

%include "asm/a20.inc"
%include "asm/cpumode.inc"
%include "asm/mem.inc"
%include "asm/output.inc"

bits 16
section .text.head

; Will be at 0x8000
global stage2_start
stage2_start:

    ; There is current disk number in DL

    call clear_screen

    call a20_ensure

    call detect_memory

    call switch_to_unreal

    push test_msg
    call print
    
    jmp $

section .data
    boot_disk_id: db 0
    test_msg: db 'I have a surprise for you! Deploying surprise in 5...4...', 10, 0

