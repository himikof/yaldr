; asmsyntax=nasm

; Disk address packet for int 0x13, ah=0x42
struc disk_packet_t
    .size resb 1
    .pd1 resb 1
    .sectors resw 1
    .buf_offset resw 1
    .buf_segment resw 1
    .start_lba resd 1
    .upper_lba resd 1
endstruc
