bits 64

; ============================================================
; x64-asm-scheduler
;
; Standalone Linux x86-64 ELF
;
; Build:
;
;   nasm -f bin baremetal-cron.asm -o baremetal-cron-single
;
; Run:
;
;   ./baremetal-cron-single
;
; ============================================================

%define SYS_read            0
%define SYS_write           1
%define SYS_open            2
%define SYS_close           3
%define SYS_mkdir           83
%define SYS_getdents64      217
%define SYS_clock_gettime   228
%define SYS_exit            60

%define CLOCK_REALTIME      0

%define O_RDONLY            0
%define O_WRONLY            1
%define O_CREAT             64
%define O_EXCL              128

%define DT_REG              8

org 0x400000


; ============================================================
; ELF64 HEADER
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
    ; mkdir backup directory
    ; --------------------------------------------------------

    mov eax, SYS_mkdir

    mov rdi, backup_path

    mov esi, 0755o

    syscall


    ; --------------------------------------------------------
    ; Open target directory
    ; --------------------------------------------------------

    mov eax, SYS_open

    mov rdi, target_path

    mov esi, O_RDONLY

    xor edx, edx

    syscall

    test rax, rax

    js error

    mov r12, rax


    ; --------------------------------------------------------
    ; Read directory entries
    ; --------------------------------------------------------

    mov eax, SYS_getdents64

    mov rdi, r12

    mov rsi, directory_buffer

    mov edx, 32768

    syscall

    test rax, rax

    js error_with_fd

    jz finish


    mov r13, rax

    xor r14d, r14d


; ============================================================
; Directory loop
; ============================================================

entry_loop:

    cmp r14, r13

    jae finish


    lea rbx, [directory_buffer + r14]


    movzx ecx, word [rbx + 16]

    test ecx, ecx

    jz error_with_fd


    ; Only regular files.
    cmp byte [rbx + 18], DT_REG

    jne advance


    lea rsi, [rbx + 19]


    ; Ignore hidden entries.
    cmp byte [rsi], '.'

    je advance


    ; --------------------------------------------------------
    ; Build source path
    ; --------------------------------------------------------

    mov rdi, source_path

    mov rsi, target_path

    call copy_string


    dec rax

    mov byte [source_path + rax], '/'

    inc rax


    mov rdi, source_path

    add rdi, rax

    lea rsi, [rbx + 19]

    call copy_string


    ; --------------------------------------------------------
    ; Open source file
    ; --------------------------------------------------------

    mov eax, SYS_open

    mov rdi, source_path

    mov esi, O_RDONLY

    xor edx, edx

    syscall

    test rax, rax

    js advance

    mov r11, rax


    ; --------------------------------------------------------
    ; Read source
    ; --------------------------------------------------------

    mov eax, SYS_read

    mov rdi, r11

    mov rsi, file_buffer

    mov edx, 32768

    syscall

    mov r10, rax


    ; Close source.
    push r10

    mov eax, SYS_close

    mov rdi, r11

    syscall

    pop r10


    test r10, r10

    js advance


    ; --------------------------------------------------------
    ; Get timestamp
    ; --------------------------------------------------------

    mov eax, SYS_clock_gettime

    mov edi, CLOCK_REALTIME

    mov rsi, timestamp

    syscall

    test rax, rax

    js advance


    ; --------------------------------------------------------
    ; Build destination path
    ;
    ; /tmp/my_project/backups/<filename>.<unix-seconds>
    ; --------------------------------------------------------

    mov rdi, destination_path

    mov rsi, backup_path

    call copy_string


    dec rax

    mov byte [destination_path + rax], '/'

    inc rax


    mov rdi, destination_path

    add rdi, rax

    lea rsi, [rbx + 19]

    call copy_string


    mov rdi, destination_path

    call strlen


    mov byte [destination_path + rax], '.'

    inc rax


    ; Convert timestamp.
    mov rdi, number_buffer

    mov rsi, [timestamp]

    call u64_to_dec


    ; Append timestamp.
    mov rdi, destination_path

    call strlen

    add rdi, rax

    mov rsi, number_buffer

    call copy_string


    ; --------------------------------------------------------
    ; Create destination
    ; --------------------------------------------------------

    mov eax, SYS_open

    mov rdi, destination_path

    mov esi, O_WRONLY | O_CREAT | O_EXCL

    mov edx, 0644o

    syscall

    test rax, rax

    js advance

    mov r11, rax


    ; --------------------------------------------------------
    ; Write backup
    ; --------------------------------------------------------

    test r10, r10

    jz close_backup


    mov eax, SYS_write

    mov rdi, r11

    mov rsi, file_buffer

    mov rdx, r10

    syscall


close_backup:

    mov eax, SYS_close

    mov rdi, r11

    syscall


; ============================================================
; Next entry
; ============================================================

advance:

    movzx eax, word [rbx + 16]

    add r14, rax

    jmp entry_loop


; ============================================================
; Finish
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
; Error with open directory
; ============================================================

error_with_fd:

    mov eax, SYS_close

    mov rdi, r12

    syscall


; ============================================================
; Error
; ============================================================

error:

    mov eax, SYS_write

    mov edi, 2

    mov rsi, error_message

    mov edx, error_length

    syscall


    mov edi, 1

    mov eax, SYS_exit

    syscall


; ============================================================
; strlen
;
; rdi = string
; rax = length
; ============================================================

strlen:

    xor eax, eax

.len_loop:

    cmp byte [rdi + rax], 0

    je .done

    inc rax

    jmp .len_loop

.done:

    ret


; ============================================================
; copy_string
;
; rdi = destination
; rsi = source
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
; u64_to_dec
;
; rdi = destination
; rsi = unsigned 64-bit integer
; ============================================================

u64_to_dec:

    mov rax, rsi

    test rax, rax

    jnz .convert


    mov byte [rdi], '0'

    mov byte [rdi + 1], 0

    ret


.convert:

    xor ecx, ecx

    mov r8, 10


.divide:

    xor edx, edx

    div r8

    add dl, '0'

    push rdx

    inc ecx

    test rax, rax

    jnz .divide


    xor eax, eax


.write:

    pop rdx

    mov [rdi + rax], dl

    inc rax

    loop .write


    mov byte [rdi + rax], 0

    ret


; ============================================================
; Read-only data
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
; Storage
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

    times 32768 db 0


file_buffer:

    times 32768 db 0


filesize equ $ - $$
