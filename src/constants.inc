; ============================================================
; Linux x86-64 constants
; ============================================================

; System calls
%define SYS_read            0
%define SYS_write           1
%define SYS_open            2
%define SYS_close           3
%define SYS_mkdir           83
%define SYS_getdents64      217
%define SYS_clock_gettime   228
%define SYS_exit            60

; clock_gettime
%define CLOCK_REALTIME      0

; open flags
%define O_RDONLY            0
%define O_WRONLY            1
%define O_CREAT             64
%define O_EXCL              128

; linux_dirent64 d_type
%define DT_REG              8

; File descriptors
%define STDOUT              1
%define STDERR              2
