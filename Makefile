NASM ?= nasm
LD ?= ld

.PHONY: all single test release clean

all: baremetal-cron

baremetal-cron: build/main.o build/utils.o build/data.o
	$(LD) -o $@ $^

build/main.o: src/main.asm src/constants.inc
	mkdir -p build
	$(NASM) -f elf64 src/main.asm -o $@

build/utils.o: src/utils.asm src/constants.inc
	mkdir -p build
	$(NASM) -f elf64 src/utils.asm -o $@

build/data.o: src/data.asm
	mkdir -p build
	$(NASM) -f elf64 src/data.asm -o $@

single: baremetal-cron-single

baremetal-cron-single: baremetal-cron.asm
	$(NASM) -f bin $< -o $@
	chmod +x $@

release: all single
	strip --strip-all baremetal-cron

test: all single
	./tests/test.sh

clean:
	rm -rf build baremetal-cron baremetal-cron-single
