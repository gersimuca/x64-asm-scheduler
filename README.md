# x64-asm-scheduler

> A small Linux x86-64 backup program written in NASM assembly.

---

## What It Does

The program currently works with one target folder:

```text
/tmp/my_project/
├── file1.txt
├── file2.txt
└── backups/
    ├── file1.txt.1788290000
    └── file2.txt.1788290000
```

When you run the program, it:

1. Creates `backups/` inside the target folder.
2. Finds regular files directly inside `/tmp/my_project`.
3. Reads their contents.
4. Gets the current Unix timestamp.
5. Creates a timestamped backup for each file.
6. Writes the backup into `backups/`.
7. Leaves the original files untouched.

The current backup filename format is:

```text
filename.UNIX_TIMESTAMP
```

For example:

```text
file1.txt.1788290000
```
---

## Quick Start

### 1. Clone

Replace the repository URL with your actual GitHub repository:

```bash
git clone https://github.com/YOURNAME/x64-asm-scheduler.git
cd x64-asm-scheduler
```

### 2. Install requirements

On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install nasm binutils make
```

Check the tools:

```bash
nasm -v
ld --version
make --version
```

### 3. Build

```bash
make
```

This creates:

```text
./baremetal-cron
```

### 4. Set up a test folder

```bash
mkdir -p /tmp/my_project

printf 'hello\n' > /tmp/my_project/file1.txt
printf 'world\n' > /tmp/my_project/file2.txt
```

### 5. Run

```bash
./baremetal-cron
```

Expected output:

```text
x64-asm-scheduler: backup complete
```

### 6. Verify

```bash
ls -la /tmp/my_project/backups
```

You should see files similar to:

```text
file1.txt.1788290000
file2.txt.1788290000
```

The exact timestamp will be different on your system.

Check the backup contents:

```bash
cat /tmp/my_project/backups/file1.txt.*
cat /tmp/my_project/backups/file2.txt.*
```

Expected:

```text
hello
world
```

---

## Run the Tests

The project includes an integration test:

```bash
make test
```

The test creates temporary files, runs both executable versions, checks
that backups were created, verifies their contents, checks the backup
filenames, and cleans up afterward.

A successful run ends with:

```text
ALL TESTS PASSED
```

---

## Project Structure

```text
x64-asm-scheduler/
├── src/
│   ├── constants.inc       # Linux syscall numbers and constants
│   ├── main.asm            # Main backup logic and _start entry point
│   ├── data.asm            # Paths and messages
│   └── utils.asm           # String and number helper functions
│
├── tests/
│   └── test.sh             # Bash integration tests
│
├── docs/
│   └── ARCHITECTURE.md     # Memory layout and design decisions
│
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions build and test workflow
│
├── Makefile                # Build, test, release, and clean commands
├── baremetal-cron.asm      # Standalone single-file version
└── README.md               # Project documentation
```

---

## Build Options

### Modular build

```bash
make
```

Builds the multi-file version:

```text
baremetal-cron
```

### Single-file build

```bash
make single
```

Builds:

```text
baremetal-cron-single
```

The single-file version contains the main functionality in one assembly
source file and is useful for studying the complete executable in one
place.

### Release build

```bash
make release
```

Builds the project and strips the modular executable.

### Run tests

```bash
make test
```

Builds both versions and runs the integration tests.

### Clean

```bash
make clean
```

Removes build artifacts and generated executables.

---

## Modular vs Single-File Version

The project provides two builds.

### Modular version

The modular version separates the code into:

```text
src/
├── constants.inc
├── main.asm
├── data.asm
└── utils.asm
```

This makes the project easier to maintain and extend.

The build process is:

```text
main.asm ──────┐
utils.asm ─────┼──> NASM ──> object files ──> GNU ld
data.asm ──────┘                                  │
                                                  ▼
                                           baremetal-cron
```

### Single-file version

The standalone version is:

```text
baremetal-cron.asm
```

It contains the executable logic in one assembly file.

It is useful for Linux x86-64 ELF executable can be built
directly from assembly.

---

## How It Works

The backup process is approximately:

```text
                ./baremetal-cron
                       │
                       ▼
             Create backups directory
                       │
                       ▼
             Open /tmp/my_project
                       │
                       ▼
                getdents64()
                       │
                       ▼
             Find regular files
                       │
                       ▼
                    open()
                       │
                       ▼
                    read()
                       │
                       ▼
             clock_gettime()
                       │
                       ▼
          Create backup filename
                       │
                       ▼
                    open()
                       │
                       ▼
                   write()
                       │
                       ▼
                   close()
                       │
                       ▼
                Backup complete
```

The executable communicates directly with the Linux kernel.

There is no libc file I/O layer between the program and the kernel.

---

## Linux System Calls

The current implementation uses these Linux x86-64 system calls:

| System Call     | Purpose                        |
| --------------- | ------------------------------ |
| `open`          | Open source and backup files   |
| `read`          | Read source file contents      |
| `write`         | Write backup contents          |
| `close`         | Close file descriptors         |
| `mkdir`         | Create the backup directory    |
| `getdents64`    | Enumerate directory entries    |
| `clock_gettime` | Get the current Unix timestamp |
| `exit`          | Exit the program               |


It performs the required operations using Linux system calls.

---

## Dependencies

### Build dependencies

You need:

```text
NASM
GNU binutils / ld
GNU make
```

### Runtime dependencies

It communicates directly with the Linux kernel through system calls.

### Test dependencies

The integration test uses Bash and standard Linux command-line tools.

These are only used by the test suite, not by the backup executable.

---

## Current Limitations

### 1. Maximum File Size

The current implementation uses a fixed:

```text
32768-byte
```

buffer.

The current backup operation therefore reads at most 32 KiB from a file.

A future version can support larger files by reading and writing them in
multiple chunks:

```text
read()
  ↓
write()
  ↓
read()
  ↓
write()
  ↓
...
```

---

### 2. No Recursive Directories

The program currently checks regular files directly inside:

```text
/tmp/my_project/
```

For example:

```text
/tmp/my_project/file.txt
```

is processed.

But:

```text
/tmp/my_project/subdir/file.txt
```

is not currently processed.

Recursive directory traversal can be added later.

---

### 3. Unix Timestamp Filenames

The current filename format is:

```text
filename.UNIX_TIMESTAMP
```

For example:

```text
file.txt.1788290000
```

The timestamp is obtained with:

```text
clock_gettime(CLOCK_REALTIME)
```

A future version may convert the timestamp into a human-readable format
such as:

```text
file.txt.20260816_203245
```

---

### 4. Cron Scheduling

At the moment, you run the backup manually:

```bash
./baremetal-cron
```

The planned scheduler will eventually support a workflow similar to:

```text
cron
 │
 │ every minute
 ▼
x64-asm-scheduler
 │
 ▼
backup files
```

The current version does not modify your crontab.

---

## Safety

The current program is intentionally scoped to:

```text
/tmp/my_project
```

and creates backups under:

```text
/tmp/my_project/backups/
```

It does not recursively modify your filesystem.

For testing, use disposable files before using the program with important
data.

To remove the test directory:

```bash
rm -rf /tmp/my_project
```

Be careful with `rm -rf` and make sure the path is correct before running it.

---

## CI

The project includes GitHub Actions:

```text
.github/workflows/ci.yml
```

The CI workflow:

1. Checks out the repository.
2. Installs NASM and binutils.
3. Builds the modular executable.
4. Builds the single-file executable.
5. Runs the integration tests.

This helps ensure that changes pushed to the repository continue to
build and pass the tests.

---

## Learning Path

If you are new to x86-64 assembly, the modular version is a good place
to start.

### 1. Read the constants

```text
src/constants.inc
```

This contains Linux syscall numbers, file flags, and other constants.

### 2. Read the data

```text
src/data.asm
```

This contains the target paths and program messages.

### 3. Read the utilities

```text
src/utils.asm
```

This contains helper functions such as:

```text
strlen
copy_string
u64_to_dec
```

### 4. Read the main program

```text
src/main.asm
```

This contains the main backup logic.

### 5. Run the tests

```bash
make test
```

### 6. Study the standalone version

```text
baremetal-cron.asm
```

This lets you see the complete standalone implementation in one file.

---

## Example Session

A complete basic test can be performed with:

```bash
mkdir -p /tmp/my_project

printf 'alpha\n' > /tmp/my_project/file1.txt
printf 'beta\n' > /tmp/my_project/file2.txt

make

./baremetal-cron

ls -la /tmp/my_project/backups
```

You should see something similar to:

```text
file1.txt.1788290000
file2.txt.1788290000
```

Then:

```bash
cat /tmp/my_project/backups/file1.txt.*
```

should output:

```text
alpha
```

and:

```bash
cat /tmp/my_project/backups/file2.txt.*
```

should output:

```text
beta
```

---

## GitHub Actions

Every push or pull request can run the project's CI workflow.

The workflow builds:

```text
baremetal-cron
baremetal-cron-single
```

and runs:

```bash
make test
```

This gives the repository an automated check that the assembly project
still builds and works after changes.

---

## Contributing

Contributions and improvements are welcome.

Before submitting changes, run:

```bash
make clean
make
make single
make test
```

Make sure all tests pass.

If you add a new feature, update the relevant documentation as well.

---
