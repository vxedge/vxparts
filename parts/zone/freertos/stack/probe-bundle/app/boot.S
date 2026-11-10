/* Multiboot v1 entry for a 32-bit flat FreeRTOS kernel on QEMU's microvm: own GDT (code 0x08,
 * data 0x10), a boot stack, then main(magic, info). */
    .set MB_MAGIC, 0x1BADB002
    .set MB_FLAGS, 0x00000003
    .section .multiboot, "a"
    .align 4
    .long MB_MAGIC, MB_FLAGS, -(MB_MAGIC + MB_FLAGS)

    .section .rodata
    .align 8
gdt:
    .quad 0
    .quad 0x00CF9A000000FFFF            /* 0x08: code, base 0, 4 GiB, ring 0 */
    .quad 0x00CF92000000FFFF            /* 0x10: data */
gdt_ptr:
    .word gdt_ptr - gdt - 1
    .long gdt

    .section .bss
    .align 16
boot_stack: .skip 16384
boot_stack_top:

    .section .text
    .global _start
_start:
    cli
    mov %eax, %esi
    lgdt gdt_ptr
    ljmp $0x08, $1f
1:  mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    mov $boot_stack_top, %esp
    push %ebx                           /* multiboot info */
    push %esi                           /* multiboot magic */
    call main
2:  hlt
    jmp 2b
