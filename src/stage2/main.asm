; Stage2 code
; asmsyntax=nasm


bits 16
section .text

; Will be at 0x8000
global stage2_start
stage2_start:

    ; There is current disk number in DL

    jmp $

section .data
    boot_disk_id: db 0

