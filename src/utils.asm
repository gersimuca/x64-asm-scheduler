bits 64

%include "constants.inc"

global strlen
global print_stdout
global print_stderr
global copy_string
global u64_to_dec

section .text

; ============================================================
; strlen
;
; rdi = NUL-terminated string
; returns:
;   rax = length, excluding NUL
; ============================================================

strlen:
    xor eax, eax

.loop:
    cmp byte [rdi + rax], 0
    je .done

    inc rax
    jmp .loop

.done:
    ret


; ============================================================
; print_stdout
;
; rdi = NUL-terminated string
; ============================================================

print_stdout:
    push rdi

    call strlen

    mov rdx, rax

    pop rsi

    mov eax, SYS_write
    mov edi, STDOUT
    syscall

    ret


; ============================================================
; print_stderr
;
; rdi = NUL-terminated string
; ============================================================

print_stderr:
    push rdi

    call strlen

    mov rdx, rax

    pop rsi

    mov eax, SYS_write
    mov edi, STDERR
    syscall

    ret


; ============================================================
; copy_string
;
; rdi = destination
; rsi = source
;
; Copies the terminating NUL.
;
; returns:
;   rax = number of bytes copied including NUL
; ============================================================

copy_string:
    xor eax, eax

.loop:
    mov dl, [rsi + rax]
    mov [rdi + rax], dl

    inc rax

    test dl, dl
    jnz .loop

    ret


; ============================================================
; u64_to_dec
;
; rdi = destination
; rsi = unsigned 64-bit integer
;
; Converts integer to decimal ASCII.
;
; returns:
;   rax = number of decimal characters
; ============================================================

u64_to_dec:
    mov rax, rsi

    test rax, rax
    jnz .convert

    mov byte [rdi], '0'
    mov byte [rdi + 1], 0

    mov eax, 1
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
