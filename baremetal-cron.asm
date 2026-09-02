bits 64

; ============================================================
; x64-asm-scheduler
;
; Linux x86-64
; NASM
; syscall only
;
; No:
;   libc
;   Python
;   C
;   shell
;   external commands
;
; ============================================================

%define SYS_read          0
%define SYS_write         1
%define SYS_open          2
%define SYS_close         3
%define SYS_mkdir         83
%define SYS_getdents64    217
%define SYS_clock_gettime 228
%define SYS_exit          60

%define CLOCK_REALTIME    0

%define O_RDONLY          0
%define O_WRONLY          1
%define O_CREAT           64
%define O_EXCL            128

%define DT_REG            8

org 0x400000


; ============================================================
; ELF HEADER
; ============================================================

ehdr:

    db 0x7f
    db "ELF"

    db 2
    db 1
    db 1
    db 0

    times 8 db 0

    dw 2
    dw 0x3e

    dd 1

    dq _start

    dq phdr - $$

    dq 0

    dd 0
    dd 0

    dw 64
    dw 56

    dw 1
    dw 0
    dw 0
    dw 0


; ============================================================
; PROGRAM HEADER
; ============================================================

phdr:

    dd 1
    dd 5

    dq 0

    dq $$

    dq $$

    dq filesize

    dq filesize

    dq 0x1000


; ============================================================
; ENTRY POINT
; ============================================================

_start:

    ; --------------------------------------------------------
    ; mkdir("/tmp/my_project/backups", 0755)
    ; --------------------------------------------------------

    mov eax, SYS_mkdir

    mov rdi, backup_path

    mov esi, 0755o

    syscall


    ; --------------------------------------------------------
    ; open("/tmp/my_project", O_RDONLY)
    ; --------------------------------------------------------

    mov eax, SYS_open

    mov rdi, target_path

    mov esi, O_RDONLY

    xor edx, edx

    syscall

    test rax, rax

    js exit_error

    mov r12, rax


    ; --------------------------------------------------------
    ; getdents64()
    ; --------------------------------------------------------

    mov eax, SYS_getdents64

    mov rdi, r12

    mov rsi, directory_buffer

    mov edx, 16384

    syscall

    test rax, rax

    jle finish


    mov r13, rax

    xor r14d, r14d


; ============================================================
; DIRECTORY LOOP
; ============================================================

directory_loop:

    cmp r14, r13

    jae finish


    lea rbx, [directory_buffer + r14]


    ; reclen
    movzx ecx, word [rbx + 16]


    ; Only regular files.
    cmp byte [rbx + 18], DT_REG

    jne next_entry


    ; Filename.
    lea r15, [rbx + 19]


    ; Ignore hidden entries.
    cmp byte [r15], '.'

    je next_entry


    ; Ignore backups directory name.
    cmp byte [r15], 'b'

    jne backup_check_done

    cmp byte [r15 + 1], 'a'
    jne backup_check_done

    cmp byte [r15 + 2], 'c'
    jne backup_check_done

    cmp byte [r15 + 3], 'k'
    jne backup_check_done

    cmp byte [r15 + 4], 'u'
    jne backup_check_done

    cmp byte [r15 + 5], 'p'
    jne backup_check_done

    cmp byte [r15 + 6], 's'
    jne backup_check_done

    jmp next_entry


backup_check_done:


    ; ========================================================
    ; Build source path.
    ;
    ; target_path + "/" + filename
    ; ========================================================

    mov rdi, source_path

    mov rsi, target_path

    call copy_string


    dec rax

    mov byte [source_path + rax], '/'

    inc rax


    mov rdi, source_path

    add rdi, rax

    mov rsi, r15

    call copy_string


    ; ========================================================
    ; Open source.
    ; ========================================================

    mov eax, SYS_open

    mov rdi, source_path

    mov esi, O_RDONLY

    xor edx, edx

    syscall

    test rax, rax

    js next_entry

    mov r11, rax


    ; ========================================================
    ; Read file.
    ; ========================================================

    mov eax, SYS_read

    mov rdi, r11

    mov rsi, file_buffer

    mov edx, 16384

    syscall

    mov r10, rax


    ; close source
    mov eax, SYS_close

    mov rdi, r11

    syscall


    test r10, r10

    jle next_entry


    ; ========================================================
    ; clock_gettime()
    ; ========================================================

    mov eax, SYS_clock_gettime

    mov edi, CLOCK_REALTIME

    mov rsi, timestamp

    syscall

    test rax, rax

    js next_entry


    ; ========================================================
    ; Build destination.
    ;
    ; /tmp/my_project/backups/
    ; filename
    ; .
    ; timestamp
    ; ========================================================

    mov rdi, destination_path

    mov rsi, backup_path

    call copy_string


    dec rax

    mov byte [destination_path + rax], '/'

    inc rax


    mov rdi, destination_path

    add rdi, rax

    mov rsi, r15

    call copy_string


    dec rax

    mov byte [destination_path + rax], '.'

    inc rax


    ; ========================================================
    ; Convert timestamp seconds to decimal.
    ; ========================================================

    mov rsi, [timestamp]

    mov rdi, number_buffer

    call number_to_string


    ; ========================================================
    ; Append number.
    ; ========================================================

    mov rdi, destination_path

    call string_length

    add rdi, rax

    mov rsi, number_buffer

    call copy_string


    ; ========================================================
    ; Create destination.
    ; ========================================================

    mov eax, SYS_open

    mov rdi, destination_path

    mov esi, O_WRONLY | O_CREAT | O_EXCL

    mov edx, 0644o

    syscall

    test rax, rax

    js next_entry

    mov r11, rax


    ; ========================================================
    ; Write backup.
    ; ========================================================

    mov eax, SYS_write

    mov rdi, r11

    mov rsi, file_buffer

    mov rdx, r10

    syscall


    ; ========================================================
    ; Close backup.
    ; ========================================================

    mov eax, SYS_close

    mov rdi, r11

    syscall


; ============================================================
; NEXT DIRECTORY ENTRY
; ============================================================

next_entry:

    movzx eax, word [rbx + 16]

    add r14, rax

    jmp directory_loop


; ============================================================
; FINISH
; ============================================================

finish:

    mov eax, SYS_close

    mov rdi, r12

    syscall


    mov eax, SYS_write

    mov edi, 1

    mov rsi, success_message

    mov edx, success_length

    syscall


    xor edi, edi

    mov eax, SYS_exit

    syscall


; ============================================================
; ERROR
; ============================================================

exit_error:

    mov eax, SYS_write

    mov edi, 2

    mov rsi, error_message

    mov edx, error_length

    syscall


    mov edi, 1

    mov eax, SYS_exit

    syscall


; ============================================================
; STRING LENGTH
;
; rdi = string
; rax = length
; ============================================================

string_length:

    xor eax, eax

.string_loop:

    cmp byte [rdi + rax], 0

    je .string_done

    inc rax

    jmp .string_loop

.string_done:

    ret


; ============================================================
; STRING COPY
;
; rdi = destination
; rsi = source
;
; returns rax = bytes copied including NUL
; ============================================================

copy_string:

    xor eax, eax

.copy_loop:

    mov dl, [rsi + rax]

    mov [rdi + rax], dl

    inc rax

    test dl, dl

    jnz .copy_loop

    ret


; ============================================================
; NUMBER TO STRING
;
; rsi = unsigned 64-bit number
; rdi = destination
;
; ============================================================

number_to_string:

    mov rax, rsi

    test rax, rax

    jnz .convert_number


    mov byte [rdi], '0'

    mov byte [rdi + 1], 0

    ret


.convert_number:

    xor ecx, ecx

    mov rbx, 10


.divide:

    xor edx, edx

    div rbx

    add dl, '0'

    push rdx

    inc ecx

    test rax, rax

    jnz .divide


    xor eax, eax


.write_number:

    pop rdx

    mov [rdi + rax], dl

    inc rax

    loop .write_number


    mov byte [rdi + rax], 0

    ret


; ============================================================
; DATA
; ============================================================

target_path:

    db "/tmp/my_project", 0


backup_path:

    db "/tmp/my_project/backups", 0


success_message:

    db "x64-asm-scheduler: backup complete", 10

success_length equ $ - success_message


error_message:

    db "x64-asm-scheduler: error", 10

error_length equ $ - error_message


; ============================================================
; BSS-LIKE STORAGE
; ============================================================

align 8

timestamp:

    dq 0
    dq 0


source_path:

    times 4096 db 0


destination_path:

    times 4096 db 0


number_buffer:

    times 32 db 0


directory_buffer:

    times 16384 db 0


file_buffer:

    times 16384 db 0


filesize equ $ - $$
