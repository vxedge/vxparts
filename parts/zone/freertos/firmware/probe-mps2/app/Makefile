# Run by build.sh inside the builder: make K=<kernel> T=<tcp> D=<demo> firmware.elf
# D is FreeRTOS's FreeRTOS_Plus_TCP_Echo_Qemu_mps2 demo, for its startup code, newlib stubs,
# linker script and the board's CMSIS headers.
CC = arm-none-eabi-gcc
K ?= ../kernel
T ?= ../tcp
D ?= ../demo
NIC := $(T)/source/portable/NetworkInterface/MPS2_AN385

SRC := main.c $(D)/startup.c $(D)/syscalls.c \
	$(K)/tasks.c $(K)/list.c $(K)/queue.c $(K)/timers.c $(K)/event_groups.c \
	$(K)/portable/GCC/ARM_CM3/port.c $(K)/portable/MemMang/heap_4.c \
	$(wildcard $(T)/source/*.c) \
	$(T)/source/portable/BufferManagement/BufferAllocation_2.c \
	$(NIC)/NetworkInterface.c $(NIC)/ether_lan9118/smsc9220_eth_drv.c

INC := -I. -I$(D) -I$(D)/CMSIS -I$(K)/include -I$(K)/portable/GCC/ARM_CM3 \
	-I$(T)/source/include -I$(T)/source/portable/Compiler/GCC -I$(NIC)/ether_lan9118

CFLAGS := -mthumb -mcpu=cortex-m3 -Os -ffunction-sections -fdata-sections -Wall \
	-ffile-prefix-map=$(CURDIR)=app -ffile-prefix-map=$(abspath $(K))=kernel \
	-ffile-prefix-map=$(abspath $(T))=tcp -ffile-prefix-map=$(abspath $(D))=demo $(INC)
LDFLAGS := -T $(D)/mps2_m3.ld -Wl,--gc-sections -Wl,--build-id=none \
	-nostartfiles -specs=nano.specs -specs=nosys.specs

BUILD := obj
OBJ := $(patsubst %.c,$(BUILD)/%.o,$(notdir $(SRC)))
vpath %.c $(sort $(dir $(SRC)))

firmware.elf: $(OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@
	arm-none-eabi-size $@

$(BUILD)/%.o: %.c FreeRTOSConfig.h FreeRTOSIPConfig.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD):
	mkdir -p $@
