; Stage1 boot code
; asmsyntax=nasm

%include "asm/disk.inc"
%include "asm/stage1_common.inc"

BITS 16

section .text

; Will be at 0x7c00
global stage1_start
stage1_start:

    ; There is current disk number in DL

    ; Clear data segments
    xor eax, eax
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax
    
    ; Init stack (1 KB)
    mov sp, 0x0900

    ; Save DL
    mov [boot_disk_id], dl

    ; Relocate self to 0x7E00
    mov si, 0x7c00
    mov di, 0x7e00
    mov cx, 256
    rep movsw
    ; Make far jump (setting CS to 0)
    jmp 0:0x7e00 + relocated - stage1_start

relocated:
    ; Clear the screen
    call clear_screen
    ; Save ES
    push es
    mov bp, sp
    ; Determine the drive to load from
    cmp byte [stage2_drive], 0xFF
    je .use_boot_drive
    mov dl, [stage2_drive]
    jmp .drive_determined
.use_boot_drive:
    mov dl, [boot_disk_id]
.drive_determined:
    test dl, 0x80
    jz .load_from_floppy
    ; Start loading stage2 from hdd
    sub sp, 16
    disk_packet equ esp       ; 16 bytes
    mov bx, [stage2_size]
    ; Construct a disk_packet_t on stack
    push bp
    lea bp, [disk_packet]
    mov byte [bp + disk_packet_t.size], 16
    mov byte [bp + disk_packet_t.pd1], 0
    mov ax, bx
    and ax, 0x003F ; read 64 sectors at once
    mov [bp + disk_packet_t.sectors], ax
    mov word [bp + disk_packet_t.buf_offset], 0
    mov word [bp + disk_packet_t.buf_segment], 0x0800
    mov eax, [stage2_block]
    mov [bp + disk_packet_t.start_lba], eax
    mov dword [bp + disk_packet_t.upper_lba], 0
    lea si, [bp]
    pop bp
    ; Actual stage2 load
.hd_load_loop:
    mov ah, 0x42
    int 0x13
    jc .error
    sub bx, [disk_packet + disk_packet_t.sectors]
    jz .stage2_ready
    mov ax, bx
    and ax, 0x003F
    mov [disk_packet + disk_packet_t.sectors], ax
    jmp .hd_load_loop

.load_from_floppy:
    push dx
    sectorsPerTrack equ 18
    numberOfHeads equ 2
    mov eax, [stage2_block]
    mov si, [stage2_size]
    xor dx, dx
    mov bx, sectorsPerTrack
    div bx
    inc dl
    mov cl, dl
    ; Now cl == Sector
    xor dx, dx
    mov dh, al
    and dh, 1
    ; Now dh == Head
    shr al, 1
    mov ch, al
    ; Now ch == Cylinder
    pop ax
    mov dl, al
    ; Set buffer ptr
    mov ax, 0x0800
    mov es, ax
    xor bx, bx
    mov al, sectorsPerTrack + 1
    sub al, cl ; read the rest of the first track
    xor ah, ah
    cmp ax, si
    jbe .fd_load_loop
    mov ax, si
    
.fd_load_loop:
    mov di, ax
    mov ah, 0x02
    int 0x13
    jc .error
    xor ah, ah
    sub si, ax
    jz .stage2_ready
    ; Update CHS
    mov cl, 1 ; S = 1
    btc dx, 8 ; Invert H
    adc ch, 0 ; Increment C, if needed
    ; Update buffer ptr
    shl ax, 5
    mov bx, es
    add bx, ax
    mov es, bx
    xor bx, bx
    mov ax, sectorsPerTrack
    cmp ax, si
    jae .fd_load_loop
    mov ax, si
    jmp .fd_load_loop
    
.stage2_ready:
    push test_msg
    call print
    add sp, 2
    ; Jump to stage 2
    mov dl, [boot_disk_id]
    mov sp, bp
    pop es
    jmp 0:0x8000

.error:
    push error_msg
    call print
    add sp, 2
    jmp $

section .data
    boot_disk_id: db 0
    error_msg: db 'Stage1 failed',0
    test_msg: db 'Ready',0

section .patchable

    ; TO BE PATCHED IN (8 bytes)
    stage2_block: dd 0x34333231
    stage2_size: dw 0x3635
    stage2_drive: db 0x37

section .signature
    dw 0x0000
    dw 0xAA55
