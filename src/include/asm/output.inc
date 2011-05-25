; asmsyntax=nasm

extern print
extern putc
extern clear_screen


%macro printline 1+
    [section .data]
    %%msg: db %1, 0
    __SECT__
    push dword %%msg
    call print
    add esp,4
%endmacro
