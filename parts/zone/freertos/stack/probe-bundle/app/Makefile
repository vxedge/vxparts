K ?= ../kernel
T ?= ../tcp
LIBGCC := $(shell gcc -m32 -print-libgcc-file-name)
CFLAGS = -m32 -ffreestanding -fno-pic -fno-stack-protector -fno-asynchronous-unwind-tables -O2 -Wall \
	-mno-ms-bitfields -mgeneral-regs-only -ffile-prefix-map=$(CURDIR)=app -ffile-prefix-map=$(abspath $(K))=kernel \
	-ffile-prefix-map=$(abspath $(T))=tcp -I. -I$(K)/include -I$(K)/portable/GCC/IA32_flat \
	-I$(T)/source/include -I$(T)/source/portable/Compiler/GCC
TCP_SRC = $(notdir $(wildcard $(T)/source/*.c)) BufferAllocation_2.c
OBJS = boot.o portASM.o main.o virtio_net.o libc.o tasks.o list.o queue.o event_groups.o port.o heap_4.o \
	$(TCP_SRC:.c=.o)
vpath %.c $(K) $(K)/portable/GCC/IA32_flat $(K)/portable/MemMang $(T)/source $(T)/source/portable/BufferManagement
vpath %.S $(K)/portable/GCC/IA32_flat

kernel.elf: $(OBJS) link.ld
	ld -m elf_i386 --no-warn-rwx-segments -z noexecstack --build-id=none -T link.ld -o $@ $(OBJS) $(LIBGCC)

%.o: %.c FreeRTOSConfig.h FreeRTOSIPConfig.h
	gcc $(CFLAGS) -c $< -o $@

%.o: %.S
	gcc $(CFLAGS) -c $< -o $@
