; Stage1 boot code
; asmsyntax=nasm

%define STAGE1

%include "asm/disk_private.inc"
%include "asm/stage1/util.inc"

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
    mov [boot_disk_id - 512], dl

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
    jz .l1
        mov bx, .hd_load_sector
        jmp .l2
    .l1:
        mov bx, .fd_load_sector
    .l2:
    ; Generic load code
    ;  edx == function ptr
    dec word [stage2_size]
    xor esi, esi ; loaded sectors count
    ; Set buffer ptr
    mov ax, 0x0800
    mov es, ax
    xor cx, cx
    mov eax, [stage2_block]
    push bx
    call bx
    pop bx
    ; Update buffer ptr
    mov ax, es
    add ax, 0x20
    mov es, ax
    BLOCK_TABLE equ 0x8100
    .load_loop:
        cmp si, [stage2_size]
        je .stage2_ready
        mov eax, [BLOCK_TABLE + 4 * esi]
        push bx
        call bx
        pop bx
        ; Update buffer ptr
        mov ax, es
        add ax, 0x20
        mov es, ax
        inc si
    jmp .load_loop

.hd_load_sector:
    ; eax == LBA to load
    ; es:cx == buffer ptr
    ; dl == drive
    ; must preserve bx
    push si
    sub sp, 16
%define    disk_packet esp       ; 16 bytes
    ; Construct a disk_packet_t on stack
    push bp
    lea bp, [disk_packet]
    mov byte [bp + disk_packet_t.size], 16
    mov byte [bp + disk_packet_t.pd1], 0
    mov word [bp + disk_packet_t.sectors], 1
    mov word [bp + disk_packet_t.buf_offset], cx
    mov word [bp + disk_packet_t.buf_segment], es
    mov [bp + disk_packet_t.start_lba], eax
    mov dword [bp + disk_packet_t.upper_lba], 0
    lea si, [bp]
    pop bp
    ; Actual sector load
    mov ah, 0x42
    int 0x13
    jc .error
    mov ax, [disk_packet + disk_packet_t.sectors]
    add sp, 16
    pop si
    ret
    
.fd_load_sector:
    ; eax == LBA to load
    ; es:cx == buffer ptr
    ; dl == drive
    ; must preserve bx
    sectorsPerTrack equ 18
    push bx
    push cx
    push dx
    xor dx, dx
    mov cx, sectorsPerTrack
    div cx
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
    pop bx
    mov al, 1 ; Read 1 sector
    mov ah, 0x02
    int 0x13
    jc .error
    mov cx, bx
    xor ah, ah
    pop bx
    ret

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
