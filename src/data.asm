bits 64

section .rodata

target_path:
    db "/tmp/my_project", 0

backup_path:
    db "/tmp/my_project/backups", 0

success_message:
    db "x64-asm-scheduler: backup complete", 10, 0

error_message:
    db "x64-asm-scheduler: error", 10, 0
