bits 64

; ============================================================
; x64-asm-scheduler
;
; Standalone Linux x86-64 ELF executable.
;
; Build:
;
;   nasm -f bin baremetal-cron.asm -o baremetal-cron-single
;   chmod +x baremetal-cron-single
;
; ============================================================

; ------------------------------------------------------------
; Linux x86-64 syscall numbers
; ------------------------------------------------------------

%define SYS_read            0
%define SYS_write           1
%define SYS_open            2
%define SYS_close           3
%define SYS_mkdir           83
%define SYS_getdents64      217
%define SYS_clock_gettime   228
%define SYS_exit            60

; ------------------------------------------------------------
; Constants
; ------------------------------------------------------------

%define CLOCK_REALTIME      0

%define O_RDONLY            0
%define O_WRONLY            1
%define O_CREAT             64
%define O_EXCL              128

%define DT_REG              8

%define STDOUT              1
%define STDERR              2

; ------------------------------------------------------------
; ELF constants
; ------------------------------------------------------------

%define ELFCLASS64         2
%define ELFDATA2LSB        1
%define EV_CURRENT         1
%define ELFOSABI_SYSV      0

%define ET_EXEC            2
%define EM_X86_64          62

%define PT_LOAD            1

; RWX is intentional here because this flat single-segment
; executable contains both code and writable buffers.
%define PF_R               4
%define PF_W               2
%define PF_X               1

org 0x400000


; ============================================================
; ELF64 HEADER
;
; struct Elf64_Ehdr:
;
;   unsigned char e_ident[16];
;   Elf64_Half    e_type;
;   Elf64_Half    e_machine;
;   Elf64_Word    e_version;
;   Elf64_Addr    e_entry;
;   Elf64_Off     e_phoff;
;   Elf64_Off     e_shoff;
;   Elf64_Word    e_flags;
;   Elf64_Half    e_ehsize;
;   Elf64_Half    e_phentsize;
;   Elf64_Half    e_phnum;
;   Elf64_Half    e_shentsize;
;   Elf64_Half    e_shnum;
;   Elf64_Half    e_shstrndx;
; ============================================================

ehdr:

    ; e_ident[0..3] = ELF magic
    db 0x7f
    db "ELF"

    ; EI_CLASS
    db ELFCLASS64

    ; EI_DATA
    db ELFDATA2LSB

    ; EI_VERSION
    db EV_CURRENT

    ; EI_OSABI
    db ELFOSABI_SYSV

    ; EI_ABIVERSION
    db 0

    ; EI_PAD[7]
    times 7 db 0


    ; e_type
    dw ET_EXEC

    ; e_machine
    dw EM_X86_64

    ; e_version
    dd EV_CURRENT

    ; e_entry
    dq _start

    ; e_phoff
    dq phdr - $$

    ; e_shoff
    dq 0

    ; e_flags
    dd 0

    ; e_ehsize
    dw 64

    ; e_phentsize
    dw 56

    ; e_phnum
    dw 1

    ; e_shentsize
    dw 0

    ; e_shnum
    dw 0

    ; e_shstrndx
    dw 0


; ============================================================
; ELF64 PROGRAM HEADER
;
; struct Elf64_Phdr:
;
;   Word      p_type;
;   Word      p_flags;
;   Offset    p_offset;
;   Addr      p_vaddr;
;   Addr      p_paddr;
;   Xword     p_filesz;
;   Xword     p_memsz;
;   Xword     p_align;
; ============================================================

phdr:

    ; p_type
    dd PT_LOAD

    ; p_flags
    dd PF_R | PF_W | PF_X

    ; p_offset
    dq 0

    ; p_vaddr
    dq $$

    ; p_paddr
    dq $$

    ; p_filesz
    dq filesize

    ; p_memsz
    dq filesize

    ; p_align
    dq 0x1000


; ============================================================
; ENTRY POINT
; ============================================================

_start:

    ; --------------------------------------------------------
    ; mkdir("/tmp/my_project/backups", 0755)
    ;
    ; Existing-directory failure is harmless because the
    ; target directory is opened immediately afterward.
    ; --------------------------------------------------------

    mov eax, SYS_mkdir
    mov rdi, backup_path
    mov esi, 0755o
    syscall


    ; --------------------------------------------------------
    ; Open target directory.
    ;
    ; r12 = directory fd
    ;
    ; r12 is safe across Linux syscall instructions.
    ; r11 is NOT safe because syscall clobbers it.
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
    ; Read directory entries.
    ;
    ; getdents64(directory_fd, buffer, 32768)
    ; --------------------------------------------------------

    mov eax, SYS_getdents64
    mov rdi, r12
    mov rsi, directory_buffer
    mov edx, 32768
    syscall

    test rax, rax
    js error_with_fd

    jz finish


    ; Number of bytes returned by getdents64.
    mov r13, rax

    ; Current directory-buffer offset.
    xor r14d, r14d

    ; Number of successful backups.
    xor r15d, r15d


; ============================================================
; DIRECTORY ENTRY LOOP
; ============================================================

entry_loop:

    cmp r14, r13
    jae finish


    ; rbx = current linux_dirent64 record.
    lea rbx, [directory_buffer + r14]


    ; --------------------------------------------------------
    ; Validate d_reclen.
    ; --------------------------------------------------------

    movzx ecx, word [rbx + 16]

    cmp ecx, 19
    jb error_with_fd


    ; --------------------------------------------------------
    ; Only process regular files.
    ;
    ; linux_dirent64:
    ;
    ;   offset 18 = d_type
    ;   offset 19 = d_name
    ; --------------------------------------------------------

    cmp byte [rbx + 18], DT_REG
    jne advance


    lea rsi, [rbx + 19]


    ; --------------------------------------------------------
    ; Skip names beginning with '.'.
    ; --------------------------------------------------------

    cmp byte [rsi], '.'
    je advance


    ; --------------------------------------------------------
    ; Build:
    ;
    ; /tmp/my_project/<filename>
    ;
    ; source_path
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
    ;
    ; r8 = source fd
    ;
    ; r8 is preserved by syscall.
    ; --------------------------------------------------------

    mov eax, SYS_open
    mov rdi, source_path
    mov esi, O_RDONLY
    xor edx, edx
    syscall

    test rax, rax
    js advance

    mov r8, rax


    ; --------------------------------------------------------
    ; Read source file into 32 KiB buffer.
    ;
    ; r10 = number of bytes read
    ; --------------------------------------------------------

    mov eax, SYS_read
    mov rdi, r8
    mov rsi, file_buffer
    mov edx, 32768
    syscall

    mov r10, rax


    ; --------------------------------------------------------
    ; Close source.
    ; --------------------------------------------------------

    mov eax, SYS_close
    mov rdi, r8
    syscall


    ; read() error
    test r10, r10
    js advance


    ; --------------------------------------------------------
    ; Get current Unix timestamp.
    ;
    ; struct timespec:
    ;
    ;   tv_sec  = offset 0
    ;   tv_nsec = offset 8
    ; --------------------------------------------------------

    mov eax, SYS_clock_gettime
    mov edi, CLOCK_REALTIME
    mov rsi, timestamp
    syscall

    test rax, rax
    js advance


    ; --------------------------------------------------------
    ; Build:
    ;
    ; /tmp/my_project/backups/<filename>.<unix-seconds>
    ;
    ; destination_path
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


    ; --------------------------------------------------------
    ; Find end of destination path.
    ; --------------------------------------------------------

    mov rdi, destination_path
    call strlen


    ; Append '.'
    mov byte [destination_path + rax], '.'
    inc rax


    ; --------------------------------------------------------
    ; Convert timestamp seconds to decimal.
    ;
    ; u64_to_dec uses r8 internally, which is now available
    ; because the source fd has already been closed.
    ; --------------------------------------------------------

    mov rdi, number_buffer
    mov rsi, [timestamp]

    call u64_to_dec


    ; --------------------------------------------------------
    ; Append decimal timestamp.
    ; --------------------------------------------------------

    mov rdi, destination_path
    call strlen

    add rdi, rax

    mov rsi, number_buffer

    call copy_string


    ; --------------------------------------------------------
    ; Create backup file.
    ;
    ; r9 = destination fd
    ;
    ; O_EXCL prevents overwriting an existing backup.
    ; --------------------------------------------------------

    mov eax, SYS_open

    mov rdi, destination_path

    mov esi, O_WRONLY | O_CREAT | O_EXCL

    mov edx, 0644o

    syscall

    test rax, rax
    js advance

    mov r9, rax


    ; --------------------------------------------------------
    ; Empty source file?
    ;
    ; Empty files are valid backups.
    ; --------------------------------------------------------

    test r10, r10
    jz close_backup


    ; --------------------------------------------------------
    ; Write source contents.
    ;
    ; For this compact implementation, one write is expected
    ; to write the entire 32 KiB-or-smaller buffer.
    ; --------------------------------------------------------

    mov eax, SYS_write

    mov rdi, r9

    mov rsi, file_buffer

    mov rdx, r10

    syscall


    ; --------------------------------------------------------
    ; Verify complete write.
    ;
    ; If it was partial or failed, close the file and do not
    ; count it as a successful backup.
    ; --------------------------------------------------------

    cmp rax, r10
    jne backup_failed


close_backup:

    mov eax, SYS_close
    mov rdi, r9
    syscall

    inc r15

    jmp advance


backup_failed:

    mov eax, SYS_close
    mov rdi, r9
    syscall

    jmp advance


; ============================================================
; ADVANCE DIRECTORY ENTRY
; ============================================================

advance:

    movzx eax, word [rbx + 16]

    add r14, rax

    jmp entry_loop


; ============================================================
; NORMAL FINISH
; ============================================================

finish:

    mov eax, SYS_close
    mov rdi, r12
    syscall


    ; --------------------------------------------------------
    ; If no files were backed up, report that.
    ; --------------------------------------------------------

    test r15, r15
    jz no_files


    mov eax, SYS_write

    mov edi, STDOUT

    mov rsi, success_message

    mov edx, success_length

    syscall


    xor edi, edi

    mov eax, SYS_exit

    syscall


; ============================================================
; NO FILES
; ============================================================

no_files:

    mov eax, SYS_write

    mov edi, STDOUT

    mov rsi, empty_message

    mov edx, empty_length

    syscall


    xor edi, edi

    mov eax, SYS_exit

    syscall


; ============================================================
; ERROR WHILE DIRECTORY FD IS OPEN
; ============================================================

error_with_fd:

    mov eax, SYS_close
    mov rdi, r12
    syscall


; ============================================================
; ERROR
; ============================================================

error:

    mov eax, SYS_write

    mov edi, STDERR

    mov rsi, error_message

    mov edx, error_length

    syscall


    mov edi, 1

    mov eax, SYS_exit

    syscall


; ============================================================
; strlen
;
; rdi = NUL-terminated string
; returns rax = length
; ============================================================

strlen:

    xor eax, eax


strlen_loop:

    cmp byte [rdi + rax], 0
    je strlen_done

    inc rax

    jmp strlen_loop


strlen_done:

    ret


; ============================================================
; copy_string
;
; rdi = destination
; rsi = source
;
; Returns rax = bytes copied including NUL.
; ============================================================

copy_string:

    xor eax, eax


copy_loop:

    mov dl, [rsi + rax]

    mov [rdi + rax], dl

    inc rax

    test dl, dl

    jnz copy_loop

    ret


; ============================================================
; u64_to_dec
;
; rdi = destination
; rsi = unsigned 64-bit integer
;
; Returns:
;
;   rax = number of decimal characters
; ============================================================

u64_to_dec:

    mov rax, rsi

    test rax, rax

    jnz convert_number


    mov byte [rdi], '0'
    mov byte [rdi + 1], 0

    mov eax, 1

    ret


convert_number:

    xor ecx, ecx

    mov r8, 10


divide_number:

    xor edx, edx

    div r8

    add dl, '0'

    push rdx

    inc ecx

    test rax, rax

    jnz divide_number


    xor eax, eax


write_digits:

    pop rdx

    mov [rdi + rax], dl

    inc rax

    loop write_digits


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


empty_message:

    db "x64-asm-scheduler: no regular files found", 10

empty_length equ $ - empty_message


; ============================================================
; STORAGE
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


; Size of the complete ELF image.
filesize equ $ - $$
