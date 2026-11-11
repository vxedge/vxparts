/* A UDP reflector for vxedge's qemu-mcu backend: FreeRTOS and FreeRTOS-Plus-TCP on QEMU's
 * mps2-an385 (Cortex-M3) with its LAN9118 NIC.
 *
 * An MCU has no kernel command line, so the backend passes `vx.ip=<cidr> vx.node=<id>` as the
 * semihosting command line, read here with SYS_GET_CMDLINE. The MAC is the one QEMU gave the
 * NIC, read from the LAN9118 before the driver starts. Every datagram on :9800 is echoed back.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "FreeRTOS.h"
#include "task.h"
#include "FreeRTOS_IP.h"
#include "FreeRTOS_Sockets.h"
#include "FreeRTOS_Routing.h"

#include "CMSIS/CMSDK_CM3.h"
#include "smsc9220_eth_drv.h"
#include "SMM_MPS2.h"

#define PORT 9800
#define SYS_GET_CMDLINE 0x15

static int semihost(int op, void *arg)
{
	register int r0 __asm__("r0") = op;
	register void *r1 __asm__("r1") = arg;

	__asm__ volatile("bkpt 0xAB" : "+r"(r0) : "r"(r1) : "memory");
	return r0;
}

static int get_cmdline(char *buf, int len)
{
	struct { char *buf; int len; } blk = { buf, len };

	if (semihost(SYS_GET_CMDLINE, &blk) != 0) {
		buf[0] = 0;
		return -1;
	}
	buf[blk.len < len ? blk.len : len - 1] = 0;
	return 0;
}

void vAssertCalled(const char *file, int line)
{
	taskDISABLE_INTERRUPTS();
	printf("ASSERT %s:%d\n", file, line);
	for (;;) {
	}
}

/* The value of `key=` in the command line, copied into out. */
static int arg(const char *line, const char *key, char *out, size_t len)
{
	size_t kl = strlen(key);

	for (const char *p = line; *p; p++) {
		if ((p == line || p[-1] == ' ') && strncmp(p, key, kl) == 0 && p[kl] == '=') {
			size_t n = 0;

			while (p[kl + 1 + n] && p[kl + 1 + n] != ' ') {
				n++;
			}
			if (n >= len) {
				return 0;
			}
			memcpy(out, p + kl + 1, n);
			out[n] = 0;
			return 1;
		}
	}
	return 0;
}

/* `a.b.c.d/prefix` into four address bytes and a prefix length. */
static int parse_cidr(const char *s, uint8_t ip[4], int *prefix)
{
	int part = 0, digits = 0;
	uint32_t v = 0;

	*prefix = 24;
	for (;; s++) {
		if (*s >= '0' && *s <= '9') {
			v = v * 10 + (uint32_t)(*s - '0');
			if (++digits > 3 || v > 255) {
				return -1;
			}
		} else if ((*s == '.' && part < 3) || ((*s == '/' || *s == 0) && part == 3)) {
			if (!digits) {
				return -1;
			}
			ip[part++] = (uint8_t)v;
			v = 0;
			digits = 0;
			if (*s == '/') {
				int p = 0;

				for (s++; *s >= '0' && *s <= '9'; s++) {
					p = p * 10 + (*s - '0');
				}
				*prefix = p;
				return (p >= 1 && p <= 32 && *s == 0) ? 0 : -1;
			}
			if (*s == 0) {
				return 0;
			}
		} else {
			return -1;
		}
	}
}

static char node[48] = "unknown";

static void reflector(void *unused)
{
	(void)unused;
	Socket_t s = FreeRTOS_socket(FREERTOS_AF_INET4, FREERTOS_SOCK_DGRAM, FREERTOS_IPPROTO_UDP);
	struct freertos_sockaddr me = { 0 };

	me.sin_family = FREERTOS_AF_INET4;
	me.sin_port = FreeRTOS_htons(PORT);
	if (s == FREERTOS_INVALID_SOCKET || FreeRTOS_bind(s, &me, sizeof(me)) != 0) {
		printf("vxparts: cannot bind :9800\n");
		vTaskDelete(NULL);
	}
	printf("vxparts guest up: node=%s, starting reflector :9800\n", node);
	for (;;) {
		static uint8_t buf[1500];
		struct freertos_sockaddr peer;
		socklen_t plen = sizeof(peer);
		int32_t n = FreeRTOS_recvfrom(s, buf, sizeof(buf), 0, &peer, &plen);

		if (n > 0) {
			(void)FreeRTOS_sendto(s, buf, (size_t)n, 0, &peer, plen);
		}
	}
}

void vApplicationIPNetworkEventHook_Multi(eIPCallbackEvent_t event, struct xNetworkEndPoint *ep)
{
	static int started;

	(void)ep;
	if (event == eNetworkUp && !started) {
		started = 1;
		xTaskCreate(reflector, "reflect", configMINIMAL_STACK_SIZE * 2, NULL, configMAX_PRIORITIES - 3, NULL);
	}
}

/* A probe guest needs unpredictable, not secure, numbers: xorshift seeded from SysTick and the MAC. */
static uint32_t rng_state;

BaseType_t xApplicationGetRandomNumber(uint32_t *out)
{
	if (rng_state == 0) {
		rng_state = SysTick->VAL ^ 0x9e3779b9u;
	}
	rng_state ^= rng_state << 13;
	rng_state ^= rng_state >> 17;
	rng_state ^= rng_state << 5;
	*out = rng_state;
	return pdTRUE;
}

uint32_t ulApplicationGetNextSequenceNumber(uint32_t a, uint16_t b, uint32_t c, uint16_t d)
{
	uint32_t r;

	(void)a;
	(void)b;
	(void)c;
	(void)d;
	xApplicationGetRandomNumber(&r);
	return r;
}

static const struct smsc9220_eth_dev_cfg_t nic_cfg = { .base = SMSC9220_BASE };
static struct smsc9220_eth_dev_data_t nic_data = { .state = 0 };
static const struct smsc9220_eth_dev_t nic = { &nic_cfg, &nic_data };

static NetworkInterface_t interface;
static NetworkEndPoint_t endpoint;

extern NetworkInterface_t *pxMPS2_FillInterfaceDescriptor(BaseType_t index, NetworkInterface_t *itf);

int main(void)
{
	static char line[256];
	char cidr[32];
	uint8_t ip[4], mask[4], gw[4] = { 0 }, dns[4] = { 0 }, mac[6];
	uint32_t lo = 0, hi = 0;
	int prefix;

	printf("vxparts: FreeRTOS " tskKERNEL_VERSION_NUMBER " on mps2-an385 booting\n");
	get_cmdline(line, sizeof(line));
	printf("cmdline: %s\n", line);
	arg(line, "vx.node", node, sizeof(node));
	if (!arg(line, "vx.ip", cidr, sizeof(cidr)) || parse_cidr(cidr, ip, &prefix) != 0) {
		printf("vxparts: no usable vx.ip on the command line\n");
		for (;;) {
		}
	}
	uint32_t m = prefix == 32 ? 0xffffffffu : ~(0xffffffffu >> prefix);

	for (int i = 0; i < 4; i++) {
		mask[i] = (uint8_t)(m >> (24 - 8 * i));
	}
	smsc9220_mac_regread(&nic, SMSC9220_MAC_REG_OFFSET_ADDRL, &lo);
	smsc9220_mac_regread(&nic, SMSC9220_MAC_REG_OFFSET_ADDRH, &hi);
	memcpy(mac, &lo, 4);
	memcpy(mac + 4, &hi, 2);
	printf("mac: %02x:%02x:%02x:%02x:%02x:%02x\n", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

	NVIC_SetPriority(ETHERNET_IRQn, configMAC_INTERRUPT_PRIORITY);
	pxMPS2_FillInterfaceDescriptor(0, &interface);
	FreeRTOS_FillEndPoint(&interface, &endpoint, ip, mask, gw, dns, mac);
	FreeRTOS_IPInit_Multi();
	vTaskStartScheduler();
	printf("scheduler returned\n");
	for (;;) {
	}
}
