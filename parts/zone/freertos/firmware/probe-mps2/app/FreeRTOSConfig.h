#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

void vAssertCalled(const char *file, int line);
#define configASSERT(x) if ((x) == 0) vAssertCalled(__FILE__, __LINE__)

#define configUSE_PREEMPTION                    1
#define configUSE_TIME_SLICING                  1
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configCPU_CLOCK_HZ                      ((unsigned long)25000000)   /* QEMU mps2-an385 SYSCLK */
#define configTICK_RATE_HZ                      ((TickType_t)1000)
#define configMINIMAL_STACK_SIZE                ((unsigned short)512)
#define configTOTAL_HEAP_SIZE                   ((size_t)(256 * 1024))
#define configMAX_TASK_NAME_LEN                 10
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 0
#define configMAX_PRIORITIES                    10
#define configUSE_COUNTING_SEMAPHORES           1
#define configSUPPORT_DYNAMIC_ALLOCATION        1
#define configUSE_MALLOC_FAILED_HOOK            0
#define configCHECK_FOR_STACK_OVERFLOW          0
#define configUSE_MUTEXES                       1
#define configUSE_RECURSIVE_MUTEXES             1

#define INCLUDE_vTaskDelete                     1
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_xTaskGetCurrentTaskHandle       1

/* Cortex-M3 with 8 NVIC priority bits on QEMU's CMSDK model. */
#define configKERNEL_INTERRUPT_PRIORITY         255
#define configMAX_SYSCALL_INTERRUPT_PRIORITY    4
#define configMAC_INTERRUPT_PRIORITY            5

#endif
