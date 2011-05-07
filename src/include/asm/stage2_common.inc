; asmsyntax=nasm

; main.asm
;extern loader_panic

; output.asm
extern print
extern putc
extern clear_screen

; cpumode.asm
extern switch_to_protected
extern switch_to_unreal

; mem.asm
;extern detect_memory
