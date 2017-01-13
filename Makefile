all: dirs bootable.img fdisk-multiboot-kernel.bin

dirs:
	mkdir -p bin
	mkdir -p build

bootload.o : src/bootloader.asm
	nasm -o build/bootload.o src/bootloader.asm

fdisk.o : src/fdisk.asm
	nasm -o build/fdisk.o src/fdisk.asm

bootable.img : bootload.o fdisk.o
	dd if=build/bootload.o of=bin/bootable.img
	dd if=build/fdisk.o of=bin/bootable.img bs=512 seek=1

fdisk-multiboot.o : src/fdisk-multiboot.asm
	nasm -f elf src/fdisk-multiboot.asm -o build/fdisk-multiboot.o

fdisk-multiboot-kernel.bin : fdisk-multiboot.o
	ld -melf_i386 -T src/linker.ld -o bin/fdisk-multiboot-kernel.bin build/fdisk-multiboot.o

clean:
	rm build/bootload.o build/fdisk.o build/fdisk-multiboot.o
