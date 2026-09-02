bits 64

; ============================================================
; Read-only project data
; ============================================================

section .rodata

global target_path
global backup_path
global success_message
global error_message
global empty_message

target_path:
    db "/tmp/my_project", 0

backup_path:
    db "/tmp/my_project/backups", 0

success_message:
    db "x64-asm-scheduler: backup complete", 10, 0

error_message:
    db "x64-asm-scheduler: error", 10, 0

empty_message:
    db "x64-asm-scheduler: no regular files found", 10, 0
