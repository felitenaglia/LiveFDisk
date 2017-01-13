# LiveFDisk
Final assignment at university. Course: Computer architecture. Bootable application for i386 architectures. Lists and allows to delete primary partitions on IDE disks. 
Year: 2012.

## Requirements

The project has to be compiled with `nasm` and it can be tested on a virtualized environment, such as QEMU or VirtualBox. 

## Compilation

The `Makefile` makes (under `bin` folder) two targets: 

- `bootable.img` can be loaded to a bootable device, such as a pendrive.
- `fdisk-multiboot-kernel.bin` can be used with any bootloader compatible with the multiboot specification. This version has been tested with GRUB 0.97 (GRUB Legacy) because GRUB 2 was just released at the time this piece of software was developed (2012) and it didn't have enough documentation.

## Usage

On boot, the program shows the partitions of the Primary Master disk. The disk can be changed through the keys `1-4`. Pressing `U` changes the current units (LBA or CHS). Pressing `E` enables the deletion menu. 

## TO DO

- Test it with GRUB 2
- List extended partitions
