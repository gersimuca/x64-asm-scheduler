# x64-asm-scheduler

&gt; A **547-byte** x86-64 assembly program that cron-schedules timestamped folder backups.  
&gt; Kernel syscalls only.

---

## What It Does

/tmp/my_project/
├── file1.txt
├── file2.txt
└── backups/
├── file1.txt.20260816_203245
├── file1.txt.20260816_203347   ← every minute
├── file2.txt.20260816_203245
└── file2.txt.20260816_203347


1. Creates `backups/` inside your target folder
2. Copies all files with `YYYYMMDD_HHMMSS` timestamps
3. Installs a cron job to repeat every minute
4. **Scoped to one folder** — never touches the rest of your system

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/YOURNAME/baremetal-cron.git
cd baremetal-cron

# 2. Build
make

# 3. Set up test folder
mkdir -p /tmp/my_project
echo "hello" > /tmp/my_project/file1.txt

# 4. Run
./baremetal-cron

# 5. Verify
ls /tmp/my_proje
crontab -l
```

x64-asm-scheduler/
├── src/
│   ├── constants.inc      # Syscall numbers & constants
│   ├── main.asm           # Entry point (_start)
│   ├── data.asm           # Strings, paths, argv/envp
│   └── utils.asm          # strlen, print_string, streq
├── tests/
│   ├── test_unit.py       # Python: syntax, structure, no-libc checks
│   └── test_integration.sh # Bash: end-to-end backup & cron verification
├── docs/
│   └── ARCHITECTURE.md    # Memory layout, design decisions
├── .github/workflows/
│   └── ci.yml             # GitHub Actions: build + test on every push
├── Makefile               # Multi-file and single-file builds
├── baremetal-cron.asm     # Single-file version (easier to read)
└── README.md              # This file

## Build Options

make              # Multi-file build (modular)
make single       # Single-file build
make release      # Stripped, minimal size
make test         # Run all tests
make clean        # Remove artifacts

## Why Assembly?

| Metric        | This Project | Typical C Program    |
| ------------- | ------------ | -------------------- |
| Binary size   | ~600 bytes   | ~20 KB (with libc)   |
| Dependencies  | 0            | libc, ld-linux, etc. |
| Syscalls used | 2            | 50+ via libc         |
| Startup time  | microseconds | milliseconds         |


ct/backups/
crontab -l
