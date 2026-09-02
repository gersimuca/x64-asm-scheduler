# Architecture

## Overview

`x64-asm-scheduler` is a Linux x86-64 assembly backup core.

The executable uses Linux system calls directly and does not link against
libc.

## Backup flow

The program performs the following operations:

1. Creates `/tmp/my_project/backups`.
2. Opens `/tmp/my_project`.
3. Calls `getdents64` to enumerate directory entries.
4. Selects entries whose `d_type` is `DT_REG`.
5. Builds the source path.
6. Opens the source file.
7. Reads up to 32 KiB into an assembly buffer.
8. Calls `clock_gettime(CLOCK_REALTIME)`.
9. Builds a destination filename using the Unix timestamp.
10. Creates the backup with `O_CREAT | O_EXCL`.
11. Writes the contents.
12. Closes the destination file.

## Example

Given:

```text
/tmp/my_project/
├── file1.txt
├── file2.txt
└── backups/
