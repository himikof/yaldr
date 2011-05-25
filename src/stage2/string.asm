; String routines (untested)
; asmsyntax=nasm

%include "asm/mem.inc"

BITS 16

; Returns min(maxlen, strlen(str)). Does not reference any str
; characters after maxlen - 1.
; Argument: str :: char*
; Argument: maxlen :: uint32_t
; Return value: number of chars in str (without '\0')
global strnlen
strnlen:
    push esi
%define str esp + 4
%define maxlen esp + 10
    mov ecx, [maxlen]
    mov esi, [str]
    xor al, al
    repne scasb                ; search for '\0'
                               ; now ecx == esi - strlen - 1
    mov eax, esi
    test ecx, ecx
    jz .l1
        sub eax, ecx           ; eax == esi - ecx == strlen + 1
        dec eax
    .l1:
.epilogue:
    pop esi
    ret


; Returns the number of characters up to the terminating null.
; Argument: str :: char*
; Return value: number of chars in str (without '\0')
global strlen
strlen:
    xor eax, eax
    not eax
    push eax
    push dword [esp + 6]       ; push str
    call strnlen               ; strnlen(str, (uint32_t)-1)
    add esp, 8
.epilogue:
    ret


; Copy src to string dest of size siz.  At most siz-1 characters
; will be copied.  Always NUL terminates (unless siz == 0).
; Returns strlen(src); if retval >= siz, truncation occurred.
; Argument: dest :: char*
; Argument: src :: char*
; Argument: siz :: uint32_t
; @return strlen(src)
global strlcpy
strlcpy:
    push bp
    mov bp, sp
    push edi
%define dest bp + 4
%define src bp + 8
%define size bp + 12
    push dword [src]
    call strlen
    add sp, 4
    mov edi, eax
    mov ecx, eax
    mov edx, dword [size]
    dec edx
    cmp eax, dword [size]
    cmovae ecx, edx
    push ecx
    push dword [src]
    push dword [dest]
    call memcpy
    mov ecx, dword [esp + 8]   ; beware of change
    add sp, 12
    add ecx, dword [dest]
    mov byte [ecx], 0          ; Always nul-terminate
    mov eax, edi
.epilogue:
    pop edi
    pop bp
    ret
