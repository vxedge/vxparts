#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H
#ifndef __ASSEMBLER__
#include <stdint.h>
#endif
/* KVM's local APIC timer counts at 1 GHz; the port divides by 16. */
#define configCPU_CLOCK_HZ                      1000000000UL
#define configTICK_RATE_HZ                      1000
#define configAPIC_BASE                         0xFEE00000UL
#define configUSE_PREEMPTION                    1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0
#define configUSE_COMMON_INTERRUPT_ENTRY_POINT  0
#define configMAX_API_CALL_INTERRUPT_PRIORITY   portMAX_PRIORITY
#define configMAX_PRIORITIES                    8
#define configMINIMAL_STACK_SIZE                1024
#define configISR_STACK_SIZE                    4096
#define configTOTAL_HEAP_SIZE                   (2 * 1024 * 1024)
#define configSUPPORT_DYNAMIC_ALLOCATION        1
#define configSUPPORT_STATIC_ALLOCATION         0
#define configSUPPORT_FPU                       0
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configUSE_MUTEXES                       1
#define configUSE_COUNTING_SEMAPHORES           1
#define configUSE_TIMERS                        0
#define configTICK_TYPE_WIDTH_IN_BITS           TICK_TYPE_WIDTH_32_BITS
#define configCHECK_FOR_STACK_OVERFLOW          0
#define configUSE_MALLOC_FAILED_HOOK            0
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_vTaskDelete                     1
#define INCLUDE_xTaskGetTickCount               1
#define INCLUDE_vTaskDelayUntil                 1
#ifndef __ASSEMBLER__
void vAssertCalled(const char *file, int line);
#define configASSERT(x) if (!(x)) vAssertCalled(__FILE__, __LINE__)
#endif
#endif
