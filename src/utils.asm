bits 64

global strlen
global print_string
global streq
global copy_string
global u64_to_dec

section .text

; ------------------------------------------------------------
; strlen
;
; rdi = NUL terminated string
; returns rax = string length
; ------------------------------------------------------------

strlen:
    xor eax, eax

.loop:
    cmp byte [rdi + rax], 0
    je .done

    inc rax
    jmp .loop

.done:
    ret


; ------------------------------------------------------------
; print_string
;
; rdi = NUL terminated string
; ------------------------------------------------------------

print_string:
    push rdi

    call strlen

    mov rdx, rax

    pop rsi

    mov eax, SYS_write
    mov edi, STDOUT
    syscall

    ret


; ------------------------------------------------------------
; streq
;
; rdi = string 1
; rsi = string 2
;
; returns:
;   eax = 1 equal
;   eax = 0 different
; ------------------------------------------------------------

streq:
.loop:
    mov al, [rdi]
    mov dl, [rsi]

    cmp al, dl
    jne .different

    test al, al
    je .equal

    inc rdi
    inc rsi

    jmp .loop

.equal:
    mov eax, 1
    ret

.different:
    xor eax, eax
    ret


; ------------------------------------------------------------
; copy_string
;
; rdi = destination
; rsi = source
;
; copies terminating NUL
; returns rax = number of bytes copied
; ------------------------------------------------------------

copy_string:
    xor eax, eax

.loop:
    mov dl, [rsi + rax]
    mov [rdi + rax], dl

    inc rax

    test dl, dl
    jnz .loop

    ret


; ------------------------------------------------------------
; u64_to_dec
;
; rdi = destination buffer
; rsi = unsigned integer
;
; converts integer to decimal ASCII.
;
; returns rax = number of characters.
; ------------------------------------------------------------

u64_to_dec:
    mov rax, rsi

    test rax, rax
    jnz .convert

    mov byte [rdi], '0'
    mov eax, 1
    ret

.convert:
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

.write:
    pop rdx

    mov [rdi + rax], dl

    inc rax

    loop .write

    ret
