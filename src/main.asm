bits 64

%include "constants.inc"

global _start

extern print_string
extern strlen
extern copy_string
extern u64_to_dec

section .bss

; Directory buffer
dirbuf:
    resb 16384

; Source path
source_path:
    resb 4096

; Destination path
destination_path:
    resb 4096

; Decimal number buffer
number_buffer:
    resb 32

; Time structure
timespec:
    resq 2


section .rodata

target:
    db "/tmp/my_project", 0

backup:
    db "/tmp/my_project/backups", 0

success:
    db "x64-asm-scheduler: backup complete", 10, 0

failure:
    db "x64-asm-scheduler: error", 10, 0


section .text

_start:

    ; --------------------------------------------------------
    ; Create backups directory.
    ;
    ; mkdir("/tmp/my_project/backups", 0755)
    ;
    ; EEXIST is harmless.
    ; --------------------------------------------------------

    mov eax, SYS_mkdir
    mov rdi, backup
    mov esi, 0755o
    syscall


    ; --------------------------------------------------------
    ; Open target directory.
    ;
    ; fd = open("/tmp/my_project", O_RDONLY)
    ; --------------------------------------------------------

    mov eax, SYS_open
    mov rdi, target
    mov esi, O_RDONLY
    xor edx, edx
    syscall

    test rax, rax
    js .error

    mov r12, rax


    ; --------------------------------------------------------
    ; Read directory entries.
    ;
    ; getdents64(fd, buffer, sizeof(buffer))
    ; --------------------------------------------------------

    mov eax, SYS_getdents64
    mov rdi, r12
    mov rsi, dirbuf
    mov edx, 16384
    syscall

    test rax, rax
    jle .close_directory

    mov r13, rax

    xor r14d, r14d


.next_entry:

    cmp r14, r13
    jae .close_directory


    ; rbx = current linux_dirent64
    lea rbx, [dirbuf + r14]


    ; --------------------------------------------------------
    ; linux_dirent64:
    ;
    ; offset 0  = ino
    ; offset 8  = off
    ; offset 16 = reclen
    ; offset 18 = type
    ; offset 19 = name
    ; --------------------------------------------------------

    movzx ecx, word [rbx + 16]


    ; Only regular files.
    cmp byte [rbx + 18], DT_REG
    jne .advance


    lea r15, [rbx + 19]


    ; Ignore "." and ".."
    cmp byte [r15], '.'
    je .advance


    ; Ignore "backups".
    cmp byte [r15], 'b'
    jne .process_file

    cmp byte [r15 + 1], 'a'
    jne .process_file

    cmp byte [r15 + 2], 'c'
    jne .process_file

    cmp byte [r15 + 3], 'k'
    jne .process_file

    cmp byte [r15 + 4], 'u'
    jne .process_file

    cmp byte [r15 + 5], 'p'
    jne .process_file

    cmp byte [r15 + 6], 's'
    je .advance


.process_file:

    ; --------------------------------------------------------
    ; Build source path:
    ;
    ; /tmp/my_project/<filename>
    ; --------------------------------------------------------

    mov rdi, source_path
    mov rsi, target

    call copy_string

    dec rax

    mov byte [source_path + rax], '/'

    inc rax

    mov rdi, source_path
    add rdi, rax

    mov rsi, r15

    call copy_string


    ; --------------------------------------------------------
    ; Open source file.
    ; --------------------------------------------------------

    mov eax, SYS_open
    mov rdi, source_path
    mov esi, O_RDONLY
    xor edx, edx
    syscall

    test rax, rax
    js .advance

    mov r11, rax


    ; --------------------------------------------------------
    ; Read source file.
    ; --------------------------------------------------------

    mov eax, SYS_read
    mov rdi, r11
    mov rsi, dirbuf
    mov edx, 16384
    syscall

    mov r10, rax


    ; Close source.
    mov eax, SYS_close
    mov rdi, r11
    syscall


    test r10, r10
    jle .advance


    ; --------------------------------------------------------
    ; Get realtime timestamp.
    ;
    ; clock_gettime(CLOCK_REALTIME, &timespec)
    ; --------------------------------------------------------

    mov eax, SYS_clock_gettime
    mov edi, CLOCK_REALTIME
    mov rsi, timespec
    syscall

    test rax, rax
    js .advance


    ; --------------------------------------------------------
    ; Build destination:
    ;
    ; /tmp/my_project/backups/
    ; filename
    ; .
    ; seconds
    ;
    ; Example:
    ;
    ; backups/file.txt.1771234567
    ; --------------------------------------------------------

    mov rdi, destination_path
    mov rsi, backup

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


    ; --------------------------------------------------------
    ; Convert timestamp seconds to decimal.
    ; --------------------------------------------------------

    mov rsi, [timespec]

    mov rdi, number_buffer

    call u64_to_dec

    mov rcx, rax


    ; Copy timestamp to destination.
    mov rsi, number_buffer

    mov rdi, destination_path

    add rdi, rax


    ; Recalculate filename end.
    mov rdi, destination_path

    call strlen

    mov rdi, destination_path
    add rdi, rax

    mov rsi, number_buffer

    call copy_string


    ; --------------------------------------------------------
    ; Create backup file.
    ;
    ; O_EXCL prevents overwriting an existing backup.
    ; --------------------------------------------------------

    mov eax, SYS_open

    mov rdi, destination_path

    mov esi, O_WRONLY | O_CREAT | O_EXCL

    mov edx, 0644o

    syscall

    test rax, rax
    js .advance

    mov r11, rax


    ; --------------------------------------------------------
    ; Write backup.
    ; --------------------------------------------------------

    mov eax, SYS_write

    mov rdi, r11

    mov rsi, dirbuf

    mov rdx, r10

    syscall


    ; Close backup.
    mov eax, SYS_close
    mov rdi, r11
    syscall


.advance:

    movzx eax, word [rbx + 16]

    add r14, rax

    jmp .next_entry


.close_directory:

    mov eax, SYS_close
    mov rdi, r12
    syscall


    ; --------------------------------------------------------
    ; Success.
    ; --------------------------------------------------------

    mov rdi, success
    call print_string

    xor edi, edi

    mov eax, SYS_exit
    syscall


.error:

    mov rdi, failure
    call print_string

    mov edi, 1

    mov eax, SYS_exit
    syscall
