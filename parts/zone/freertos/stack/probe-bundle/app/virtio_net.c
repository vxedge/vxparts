/* A FreeRTOS-Plus-TCP network interface for a virtio-net device on QEMU's microvm, over the
 * virtio-mmio version 2 (modern) transport.
 *
 * Polled, not interrupt driven: a task checks the receive ring every tick, so the guest needs no
 * IOAPIC set-up. One receive and one transmit queue, VIRTIO_F_VERSION_1 and VIRTIO_NET_F_MAC
 * negotiated, nothing else. Physical and virtual addresses are the same (no MMU).
 */
#include <stdint.h>
#include <string.h>

#include "FreeRTOS.h"
#include "task.h"
#include "FreeRTOS_IP.h"
#include "FreeRTOS_IP_Private.h"
#include "FreeRTOS_Routing.h"
#include "NetworkBufferManagement.h"
#include "NetworkInterface.h"

#include "virtio_net.h"

#define MMIO_BASE 0xFEB00000UL
#define MMIO_STRIDE 0x200UL
#define MMIO_SLOTS 32

#define R_MAGIC 0x000
#define R_VERSION 0x004
#define R_DEVICE_ID 0x008
#define R_DEVICE_FEATURES 0x010
#define R_DEVICE_FEATURES_SEL 0x014
#define R_DRIVER_FEATURES 0x020
#define R_DRIVER_FEATURES_SEL 0x024
#define R_QUEUE_SEL 0x030
#define R_QUEUE_NUM_MAX 0x034
#define R_QUEUE_NUM 0x038
#define R_QUEUE_READY 0x044
#define R_QUEUE_NOTIFY 0x050
#define R_INTERRUPT_STATUS 0x060
#define R_INTERRUPT_ACK 0x064
#define R_STATUS 0x070
#define R_QUEUE_DESC_LO 0x080
#define R_QUEUE_DESC_HI 0x084
#define R_QUEUE_AVAIL_LO 0x090
#define R_QUEUE_AVAIL_HI 0x094
#define R_QUEUE_USED_LO 0x0a0
#define R_QUEUE_USED_HI 0x0a4
#define R_CONFIG 0x100

#define ST_ACKNOWLEDGE 1
#define ST_DRIVER 2
#define ST_DRIVER_OK 4
#define ST_FEATURES_OK 8

#define F_NET_MAC (1UL << 5)        /* in feature word 0 */
#define F_VERSION_1 (1UL << 0)      /* bit 32: feature word 1, bit 0 */

#define QSIZE 16
#define DESC_F_WRITE 2
#define NET_HDR 12                  /* struct virtio_net_hdr with num_buffers, as VERSION_1 has it */
#define FRAME_MAX 1514
#define BUF_SIZE (NET_HDR + FRAME_MAX)

struct desc { uint64_t addr; uint32_t len; uint16_t flags, next; };
struct avail { uint16_t flags, idx, ring[QSIZE], used_event; };
struct used_elem { uint32_t id, len; };
struct used { uint16_t flags, idx; struct used_elem ring[QSIZE]; uint16_t avail_event; };

struct queue {
	struct desc desc[QSIZE] __attribute__((aligned(16)));
	struct avail avail __attribute__((aligned(2)));
	struct used used __attribute__((aligned(4)));
	uint16_t last_used;
	uint8_t buf[QSIZE][BUF_SIZE];
};

static struct queue rxq __attribute__((aligned(4096)));
static struct queue txq __attribute__((aligned(4096)));
static volatile uint32_t *dev;
static uint8_t mac[6];
static NetworkInterface_t *iface;
static uint16_t tx_next;

static inline uint32_t rd(uint32_t off) { return dev[off / 4]; }
static inline void wr(uint32_t off, uint32_t v) { dev[off / 4] = v; }
static inline void barrier(void) { __asm__ volatile("mfence" ::: "memory"); }

int virtio_net_probe(void)
{
	for (uintptr_t a = MMIO_BASE; a < MMIO_BASE + MMIO_STRIDE * MMIO_SLOTS; a += MMIO_STRIDE) {
		volatile uint32_t *r = (volatile uint32_t *)a;

		if (r[R_MAGIC / 4] == 0x74726976 && r[R_VERSION / 4] == 2 && r[R_DEVICE_ID / 4] == 1) {
			dev = r;
			return 0;
		}
	}
	return -1;
}

const uint8_t *virtio_net_mac(void) { return mac; }

static void queue_setup(uint32_t index, struct queue *q)
{
	wr(R_QUEUE_SEL, index);
	configASSERT(rd(R_QUEUE_NUM_MAX) >= QSIZE);
	wr(R_QUEUE_NUM, QSIZE);
	wr(R_QUEUE_DESC_LO, (uint32_t)(uintptr_t)q->desc);
	wr(R_QUEUE_DESC_HI, 0);
	wr(R_QUEUE_AVAIL_LO, (uint32_t)(uintptr_t)&q->avail);
	wr(R_QUEUE_AVAIL_HI, 0);
	wr(R_QUEUE_USED_LO, (uint32_t)(uintptr_t)&q->used);
	wr(R_QUEUE_USED_HI, 0);
	wr(R_QUEUE_READY, 1);
}

/* Negotiate, set up both queues, read the MAC. Called once, before the IP task starts. */
int virtio_net_init(void)
{
	if (dev == NULL && virtio_net_probe() != 0) {
		return -1;
	}
	wr(R_STATUS, 0);
	wr(R_STATUS, ST_ACKNOWLEDGE);
	wr(R_STATUS, ST_ACKNOWLEDGE | ST_DRIVER);

	wr(R_DEVICE_FEATURES_SEL, 0);
	uint32_t lo = rd(R_DEVICE_FEATURES);
	wr(R_DEVICE_FEATURES_SEL, 1);
	uint32_t hi = rd(R_DEVICE_FEATURES);
	if (!(hi & F_VERSION_1)) {
		return -2;
	}
	wr(R_DRIVER_FEATURES_SEL, 0);
	wr(R_DRIVER_FEATURES, lo & F_NET_MAC);
	wr(R_DRIVER_FEATURES_SEL, 1);
	wr(R_DRIVER_FEATURES, F_VERSION_1);
	wr(R_STATUS, ST_ACKNOWLEDGE | ST_DRIVER | ST_FEATURES_OK);
	if (!(rd(R_STATUS) & ST_FEATURES_OK)) {
		return -3;
	}

	memset(&rxq, 0, sizeof(rxq));
	memset(&txq, 0, sizeof(txq));
	queue_setup(0, &rxq);
	queue_setup(1, &txq);

	/* Every receive buffer goes to the device up front. */
	for (uint16_t i = 0; i < QSIZE; i++) {
		rxq.desc[i].addr = (uint32_t)(uintptr_t)rxq.buf[i];
		rxq.desc[i].len = BUF_SIZE;
		rxq.desc[i].flags = DESC_F_WRITE;
		rxq.avail.ring[i] = i;
	}
	barrier();
	rxq.avail.idx = QSIZE;

	if (lo & F_NET_MAC) {
		for (int i = 0; i < 6; i++) {
			mac[i] = ((volatile uint8_t *)dev)[R_CONFIG + i];
		}
	}
	wr(R_STATUS, ST_ACKNOWLEDGE | ST_DRIVER | ST_FEATURES_OK | ST_DRIVER_OK);
	barrier();
	wr(R_QUEUE_NOTIFY, 0);
	return 0;
}

/* Hand every frame the device has written to the IP task, and give the buffers back. */
static void rx_poll(void)
{
	int returned = 0;

	while (rxq.last_used != *(volatile uint16_t *)&rxq.used.idx) {
		barrier();
		struct used_elem e = rxq.used.ring[rxq.last_used % QSIZE];
		uint32_t len = e.len > NET_HDR ? e.len - NET_HDR : 0;

		if (len > 0 && len <= FRAME_MAX) {
			NetworkBufferDescriptor_t *nb = pxGetNetworkBufferWithDescriptor(len, 0);

			if (nb != NULL) {
				memcpy(nb->pucEthernetBuffer, rxq.buf[e.id] + NET_HDR, len);
				nb->xDataLength = len;
				nb->pxInterface = iface;
				nb->pxEndPoint = FreeRTOS_MatchingEndpoint(iface, nb->pucEthernetBuffer);
				IPStackEvent_t ev = { eNetworkRxEvent, nb };

				if (nb->pxEndPoint == NULL || xSendEventStructToIPTask(&ev, 0) == pdFAIL) {
					vReleaseNetworkBufferAndDescriptor(nb);
				}
			}
		}
		rxq.avail.ring[rxq.avail.idx % QSIZE] = (uint16_t)e.id;
		barrier();
		rxq.avail.idx++;
		rxq.last_used++;
		returned = 1;
	}
	if (returned) {
		barrier();
		wr(R_QUEUE_NOTIFY, 0);
	}
	/* Interrupts are not used; acknowledge so the device does not hold them pending. */
	uint32_t isr = rd(R_INTERRUPT_STATUS);

	if (isr) {
		wr(R_INTERRUPT_ACK, isr);
	}
}

static void rx_task(void *arg)
{
	(void)arg;
	for (;;) {
		rx_poll();
		vTaskDelay(1);
	}
}

static BaseType_t net_initialise(NetworkInterface_t *pxInterface)
{
	static TaskHandle_t task;

	(void)pxInterface;
	if (task == NULL) {
		xTaskCreate(rx_task, "vnet-rx", configMINIMAL_STACK_SIZE, NULL, configMAX_PRIORITIES - 2, &task);
	}
	return pdTRUE;
}

static BaseType_t net_output(NetworkInterface_t *pxInterface, NetworkBufferDescriptor_t *nb, BaseType_t release)
{
	(void)pxInterface;
	size_t len = nb->xDataLength;

	if (len <= FRAME_MAX) {
		/* Reclaim what the device has sent; the ring is far larger than what is in flight. */
		txq.last_used = *(volatile uint16_t *)&txq.used.idx;
		uint16_t i = tx_next++ % QSIZE;

		memset(txq.buf[i], 0, NET_HDR);
		memcpy(txq.buf[i] + NET_HDR, nb->pucEthernetBuffer, len);
		txq.desc[i].addr = (uint32_t)(uintptr_t)txq.buf[i];
		txq.desc[i].len = NET_HDR + len;
		txq.desc[i].flags = 0;
		txq.avail.ring[txq.avail.idx % QSIZE] = i;
		barrier();
		txq.avail.idx++;
		barrier();
		wr(R_QUEUE_NOTIFY, 1);
	}
	if (release == pdTRUE) {
		vReleaseNetworkBufferAndDescriptor(nb);
	}
	return pdTRUE;
}

static BaseType_t net_link(NetworkInterface_t *pxInterface)
{
	(void)pxInterface;
	return pdTRUE;
}

NetworkInterface_t *pxFillInterfaceDescriptor(BaseType_t xEMACIndex, NetworkInterface_t *pxInterface)
{
	(void)xEMACIndex;
	iface = pxInterface;
	memset(pxInterface, 0, sizeof(*pxInterface));
	pxInterface->pcName = "eth0";
	pxInterface->pfInitialise = net_initialise;
	pxInterface->pfOutput = net_output;
	pxInterface->pfGetPhyLinkStatus = net_link;
	FreeRTOS_AddNetworkInterface(pxInterface);
	return pxInterface;
}
