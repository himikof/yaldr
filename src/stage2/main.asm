; Stage2 code
; asmsyntax=nasm

%include "asm/stage2_common.inc"

bits 16
section .text

; Will be at 0x8000
global stage2_start
stage2_start:

    ; There is current disk number in DL

    call switch_to_unreal

    jmp $

section .data
    boot_disk_id: db 0

