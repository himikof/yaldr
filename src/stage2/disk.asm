; Disk IO routines (untested)
; asmsyntax=nasm

%include "asm/output.inc"
%include "asm/disk_private.inc"
%include "asm/mem.inc"

; Segment 0x2000 (64 KB) is the disk input buffer

INPUT_BUFFER equ 0x20000
INPUT_BUFFER_SIZE equ 0x10000
INPUT_SECTORS equ INPUT_BUFFER_SIZE >> 9

BITS 16

; Reads disk sectors.
; Param: disk number, 1 byte (padded to 4)
; Param: buffer, 4 bytes
; Param: start LBA, 4 bytes
; Param: sector count, 4 bytes
; Return value: 0 if success, non-zero if failure
global read_sectors
read_sectors:
    push bp
    mov bp, sp
    sub sp, 6
%define disk ebp + 4
%define buffer ebp + 8
%define start ebp + 12
%define count ebp + 16
%define func ebp - 2
%define remain ebp - 6
    mov ax, fd_load_sectors
    mov cx, hd_load_sectors
    test byte [disk], 0x80
    cmovnz ax, cx
    mov [func], ax
    mov ecx, [count]
    mov [remain], ecx
    .load_loop:
        test ecx, ecx
        jz .success
        mov edx, INPUT_SECTORS
        cmp eax, ecx
        cmova eax, ecx
        mov [count], eax
        push eax
        call word [func]
        pop edx
        test ax, ax
        jnz .error
        shl edx, 9
        push edx
        push dword INPUT_BUFFER
        lea eax, [buffer]
        push eax
        call memcpy
        add esp, 12
        sub [remain], edx
        mov ecx, [remain]
        jmp .load_loop
.error:
    jmp .epilogue
.success:
    xor eax, eax
.epilogue:
    mov sp, bp
    ret

fd_load_sectors:
    push es
    sectorsPerTrack equ 18
    mov edi, INPUT_BUFFER
    mov eax, edi
    shr eax, 4
    mov es, ax
    and di, 0x0F
    mov eax, [start]
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
    mov dl, [disk]
    mov al, sectorsPerTrack + 1
    sub al, cl
    mov ebx, [count]
    cmp al, bl
    cmova ax, bx
    ; Now al == min(18 + 1 - Sector, count & 0xFF) -- sectors to read
    .loop:
        mov ah, 0x02
        mov bx, di
        int 0x13
        jc .error
        xor ah, ah
        ; Update destination pointer
        mov bx, ax
        shl bx, 5
        bswap eax
        mov ax, es
        add ax, bx
        mov es, ax
        bswap eax
        cwde
        ; Update remaining sector count
        sub dword [count], eax
        jz .finished
        btc dx, 8 ; Next head
        adc ch, 0 ; Next cylinder, if head was 1
        mov al, sectorsPerTrack
        mov ebx, [count]
        cmp al, bl
        cmova ax, bx
        ; Now al == min(18, count & 0xFF) -- sectors to read
    jmp .loop
.finished:
    xor eax, eax
    jmp .epilogue
.error:
    xor eax, eax
    not eax
.epilogue:
    pop es
    ret

hd_load_sectors:
    push si
    sub sp, disk_packet_t_size
%define    disk_packet esp       ; 16 bytes
    ; Construct a disk_packet_t on stack
    push bp
    mov bp, sp
    mov eax, INPUT_BUFFER
    mov ecx, eax
    shr ecx, 4
    and ax, 0xF
    mov ebx, [start]
    mov byte [bp + disk_packet_t.size], 16
    mov byte [bp + disk_packet_t.pd1], 0
    mov word [bp + disk_packet_t.buf_offset], ax
    mov word [bp + disk_packet_t.buf_segment], cx
    mov dword [bp + disk_packet_t.start_lba], ebx
    mov dword [bp + disk_packet_t.upper_lba], 0
    pop bp
    .loop:
        mov edx, [count]
        mov eax, 0x7F
        cmp edx, eax
        cmova edx, eax
        mov word [disk_packet + disk_packet_t.sectors], dx
        mov si, sp
        ; Actual sector load
        mov dl, [disk]
        mov ah, 0x42
        int 0x13
        jc .error
        mov ax, [disk_packet + disk_packet_t.sectors]
        mov cx, ax
        shl cx, 5
        add word [disk_packet + disk_packet_t.buf_segment], cx
        add word [disk_packet + disk_packet_t.start_lba], ax
        cwde
        sub dword [count], eax
        jz .finished
        jmp .loop
.finished:
    jmp .epilogue
.error:
    xor eax, eax
    not eax
.epilogue:
    add sp, 16
    pop si
    ret
