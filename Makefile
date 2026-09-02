NASM=nasm
LD=ld

all:
	mkdir -p build
	$(NASM) -f elf64 src/main.asm -o build/main.o
	$(NASM) -f elf64 src/utils.asm -o build/utils.o
	$(LD) -o baremetal-cron build/main.o build/utils.o

single:
	$(NASM) -f bin baremetal-cron.asm -o baremetal-cron-single
	chmod +x baremetal-cron-single

release: all
	strip --strip-all baremetal-cron

clean:
	rm -rf build baremetal-cron baremetal-cron-single
