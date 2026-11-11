#ifndef FREERTOS_IP_CONFIG_H
#define FREERTOS_IP_CONFIG_H

#define ipconfigBYTE_ORDER                         pdFREERTOS_LITTLE_ENDIAN
#define ipconfigUSE_IPv4                           1
#define ipconfigUSE_IPv6                           0
#define ipconfigUSE_TCP                            0
#define ipconfigUSE_DHCP                           0
#define ipconfigUSE_DNS                            0
#define ipconfigUSE_LLMNR                          0
#define ipconfigUSE_NBNS                           0
#define ipconfigUSE_NETWORK_EVENT_HOOK             1
#define ipconfigSUPPORT_OUTGOING_PINGS             0
#define ipconfigREPLY_TO_INCOMING_PINGS            1
#define ipconfigSUPPORT_SELECT_FUNCTION            0
#define ipconfigNETWORK_MTU                        1500
#define ipconfigNUM_NETWORK_BUFFER_DESCRIPTORS     32
#define ipconfigEVENT_QUEUE_LENGTH                 (ipconfigNUM_NETWORK_BUFFER_DESCRIPTORS + 5)
#define ipconfigIP_TASK_PRIORITY                   (configMAX_PRIORITIES - 2)
#define ipconfigIP_TASK_STACK_SIZE_WORDS           (configMINIMAL_STACK_SIZE * 4)
#define ipconfigUDP_MAX_RX_PACKETS                 32
#define ipconfigUDP_TIME_TO_LIVE                   64
#define ipconfigARP_CACHE_ENTRIES                  16
#define ipconfigMAX_ARP_RETRANSMISSIONS            5
#define ipconfigMAX_ARP_AGE                        150
#define ipconfigDRIVER_INCLUDED_TX_IP_CHECKSUM     0
#define ipconfigDRIVER_INCLUDED_RX_IP_CHECKSUM     0
#define ipconfigETHERNET_DRIVER_FILTERS_FRAME_TYPES 0
#define ipconfigETHERNET_DRIVER_FILTERS_PACKETS    0
#define ipconfigZERO_COPY_RX_DRIVER                0
#define ipconfigZERO_COPY_TX_DRIVER                0
#define ipconfigHAS_DEBUG_PRINTF                   0
#define ipconfigHAS_PRINTF                         0
#define ipconfigSOCK_DEFAULT_RECEIVE_BLOCK_TIME    portMAX_DELAY
#define ipconfigSOCK_DEFAULT_SEND_BLOCK_TIME       pdMS_TO_TICKS(100)
#define ipconfigUSE_ETHERNET                       1
#define ipconfigIPv4_BACKWARD_COMPATIBLE           0
#define ipconfigCOMPATIBLE_WITH_SINGLE             0
#define ipconfigENDPOINT_DNS_ADDRESS_COUNT         1

#endif
