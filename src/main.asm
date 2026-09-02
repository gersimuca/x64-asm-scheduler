bits 64

%include "constants.inc"

global _start

extern print_stdout
extern print_stderr
extern strlen
extern copy_string
extern u64_to_dec

extern target_path
extern backup_path
extern success_message
extern error_message
extern empty_message


; ============================================================
; Storage
; ============================================================

section .bss

    align 8

directory_buffer:
    resb 32768

file_buffer:
    resb 32768

source_path:
    resb 4096

destination_path:
    resb 4096

number_buffer:
    resb 32

timestamp:
    resq 2


; ============================================================
; Code
; ============================================================

section .text

_start:

    ; --------------------------------------------------------
    ; mkdir("/tmp/my_project/backups", 0755)
    ;
    ; If the directory already exists, execution continues.
    ; --------------------------------------------------------

    mov eax, SYS_mkdir
    mov rdi, backup_path
    mov esi, 0755o
    syscall


    ; --------------------------------------------------------
    ; Open target directory.
    ;
    ; fd = open("/tmp/my_project", O_RDONLY)
    ; --------------------------------------------------------

    mov eax, SYS_open
    mov rdi, target_path
    mov esi, O_RDONLY
    xor edx, edx
    syscall

    test rax, rax
    js .error

    mov r12, rax


    ; --------------------------------------------------------
    ; Read directory entries.
    ;
    ; getdents64(fd, buffer, 32768)
    ; --------------------------------------------------------

    mov eax, SYS_getdents64
    mov rdi, r12
    mov rsi, directory_buffer
    mov edx, 32768
    syscall

    test rax, rax
    js .close_error

    jz .finish


    mov r13, rax

    ; Current offset in directory buffer.
    xor r14d, r14d

    ; Number of successful backups.
    xor r15d, r15d


; ============================================================
; Directory iteration
; ============================================================

.next_entry:

    cmp r14, r13
    jae .finish


    ; rbx = current linux_dirent64
    lea rbx, [directory_buffer + r14]


    ; linux_dirent64 layout:
    ;
    ; offset 0   : d_ino
    ; offset 8   : d_off
    ; offset 16  : d_reclen
    ; offset 18  : d_type
    ; offset 19  : d_name
    ;

    movzx ecx, word [rbx + 16]

    test ecx, ecx
    jz .close_error


    ; Only regular files.
    cmp byte [rbx + 18], DT_REG
    jne .advance


    lea rsi, [rbx + 19]


    ; Ignore hidden entries such as "." and "..".
    cmp byte [rsi], '.'
    je .advance


    ; --------------------------------------------------------
    ; Build source path:
    ;
    ; /tmp/my_project/<filename>
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
    ;
    ; Current implementation supports files up to 32768 bytes.
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


    ; read() error
    test r10, r10
    js .advance


    ; --------------------------------------------------------
    ; Get current Unix timestamp.
    ;
    ; timestamp.tv_sec is at [timestamp].
    ; --------------------------------------------------------

    mov eax, SYS_clock_gettime
    mov edi, CLOCK_REALTIME
    mov rsi, timestamp
    syscall

    test rax, rax
    js .advance


    ; --------------------------------------------------------
    ; Build destination:
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


    ; Find end of filename.
    mov rdi, destination_path

    call strlen


    ; Append ".".
    mov byte [destination_path + rax], '.'

    inc rax


    ; --------------------------------------------------------
    ; Convert Unix timestamp to decimal.
    ; --------------------------------------------------------

    mov rdi, number_buffer
    mov rsi, [timestamp]

    call u64_to_dec


    ; --------------------------------------------------------
    ; Append timestamp.
    ; --------------------------------------------------------

    mov rdi, destination_path

    call strlen

    add rdi, rax

    mov rsi, number_buffer

    call copy_string


    ; --------------------------------------------------------
    ; Create backup file.
    ;
    ; O_EXCL prevents accidental overwrite.
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
    ; Write file.
    ;
    ; Empty files are valid and require no write syscall.
    ; --------------------------------------------------------

    test r10, r10
    jz .close_backup


    mov eax, SYS_write

    mov rdi, r11

    mov rsi, file_buffer

    mov rdx, r10

    syscall


    ; We expect one complete write for this fixed-size buffer.
    cmp rax, r10
    jne .close_backup


.close_backup:

    mov eax, SYS_close

    mov rdi, r11

    syscall


    inc r15


; ============================================================
; Advance to next directory entry
; ============================================================

.advance:

    movzx eax, word [rbx + 16]

    add r14, rax

    jmp .next_entry


; ============================================================
; Normal finish
; ============================================================

.finish:

    mov eax, SYS_close

    mov rdi, r12

    syscall


    test r15, r15

    jz .no_files


    mov rdi, success_message

    call print_stdout


    xor edi, edi

    mov eax, SYS_exit

    syscall


; ============================================================
; No regular files
; ============================================================

.no_files:

    mov rdi, empty_message

    call print_stdout


    xor edi, edi

    mov eax, SYS_exit

    syscall


; ============================================================
; Error while processing directory
; ============================================================

.close_error:

    mov eax, SYS_close

    mov rdi, r12

    syscall


.error:

    mov rdi, error_message

    call print_stderr


    mov edi, 1

    mov eax, SYS_exit

    syscall
