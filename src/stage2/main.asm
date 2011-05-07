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

    call switch_to_unreal

    call clear_screen

    push test_msg
    call print
    
    jmp $

section .data
    boot_disk_id: db 0
    test_msg: db 'We are here!', 10, 0

