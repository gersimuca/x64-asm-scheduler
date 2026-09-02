#!/usr/bin/env bash

set -eu

ROOT="/tmp/my_project"

echo "[1/6] Preparing test directory..."

rm -rf "$ROOT"

mkdir -p "$ROOT/backups"

printf 'alpha\n' > "$ROOT/file1.txt"
printf 'beta\n' > "$ROOT/file2.txt"

echo "[2/6] Testing modular executable..."

./baremetal-cron

count=$(find "$ROOT/backups" -maxdepth 1 -type f | wc -l)

if [ "$count" -ne 2 ]; then
    echo "FAIL: expected 2 backup files, found $count"
    exit 1
fi

grep -R -q '^alpha$' "$ROOT/backups"
grep -R -q '^beta$' "$ROOT/backups"

echo "PASS: modular executable"


echo "[3/6] Clearing backups..."

rm -rf "$ROOT/backups"

mkdir -p "$ROOT/backups"


echo "[4/6] Testing single-file executable..."

./baremetal-cron-single

count=$(find "$ROOT/backups" -maxdepth 1 -type f | wc -l)

if [ "$count" -ne 2 ]; then
    echo "FAIL: expected 2 single-file backups, found $count"
    exit 1
fi

grep -R -q '^alpha$' "$ROOT/backups"
grep -R -q '^beta$' "$ROOT/backups"

echo "PASS: single-file executable"


echo "[5/6] Checking backup names..."

for file in "$ROOT"/backups/*; do
    name=$(basename "$file")

    case "$name" in
        file1.txt.*|file2.txt.*)
            ;;
        *)
            echo "FAIL: unexpected backup name: $name"
            exit 1
            ;;
    esac
done

echo "PASS: backup names"


echo "[6/6] Cleaning up..."

rm -rf "$ROOT"

echo
echo "ALL TESTS PASSED"
