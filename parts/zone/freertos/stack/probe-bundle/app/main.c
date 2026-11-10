/* A UDP reflector for vxedge's qemu-microvm backend, on FreeRTOS and FreeRTOS-Plus-TCP.
 *
 * The zone-backend contract hands the guest its address on the kernel command line
 * (`vx.ip=<cidr>`, `vx.node=<id>`), which QEMU passes to a Multiboot kernel. The MAC is the one
 * QEMU gave the NIC, read from the virtio device configuration, so vxedge's per-node MAC reaches
 * the wire. The payload echoes every datagram on :9800, as vxprobe does.
 */
#include <stdint.h>
#include <string.h>

#include "FreeRTOS.h"
#include "task.h"
#include "FreeRTOS_IP.h"
#include "FreeRTOS_Sockets.h"
#include "FreeRTOS_Routing.h"

#include "virtio_net.h"

#define PORT 9800

struct mbi { uint32_t flags, mem_lower, mem_upper, boot_device, cmdline; };

static inline void outb(uint16_t p, uint8_t v) { __asm__ volatile("outb %0,%1" :: "a"(v), "Nd"(p)); }
static inline uint8_t inb(uint16_t p) { uint8_t v; __asm__ volatile("inb %1,%0" : "=a"(v) : "Nd"(p)); return v; }

static void con_putc(char c)
{
	while (!(inb(0x3F8 + 5) & 0x20)) {
	}
	outb(0x3F8, (uint8_t)c);
}

static void con_puts(const char *s)
{
	while (*s) {
		if (*s == '\n') {
			con_putc('\r');
		}
		con_putc(*s++);
	}
}

static void con_u32(uint32_t v)
{
	char b[11];
	int i = 10;

	b[i] = 0;
	do {
		b[--i] = (char)('0' + v % 10);
		v /= 10;
	} while (v);
	con_puts(&b[i]);
}

void vAssertCalled(const char *file, int line)
{
	taskDISABLE_INTERRUPTS();
	con_puts("ASSERT ");
	con_puts(file);
	con_puts(":");
	con_u32((uint32_t)line);
	con_puts("\n");
	for (;;) {
		__asm__ volatile("hlt");
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
	int part = 0;
	uint32_t v = 0;
	int digits = 0;

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

static void reflector(void *arg_)
{
	(void)arg_;
	Socket_t s = FreeRTOS_socket(FREERTOS_AF_INET4, FREERTOS_SOCK_DGRAM, FREERTOS_IPPROTO_UDP);
	struct freertos_sockaddr me = { 0 };

	me.sin_family = FREERTOS_AF_INET4;
	me.sin_port = FreeRTOS_htons(PORT);
	if (s == FREERTOS_INVALID_SOCKET || FreeRTOS_bind(s, &me, sizeof(me)) != 0) {
		con_puts("vxparts: cannot bind :9800\n");
		vTaskDelete(NULL);
	}
	con_puts("vxparts guest up: node=");
	con_puts(node);
	con_puts(", starting reflector :9800\n");
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

/* A probe guest needs unpredictable, not secure, numbers: xorshift seeded from the TSC. */
static uint32_t rng_state;

BaseType_t xApplicationGetRandomNumber(uint32_t *out)
{
	if (rng_state == 0) {
		uint32_t lo, hi;

		__asm__ volatile("rdtsc" : "=a"(lo), "=d"(hi));
		rng_state = lo ^ (hi << 7) ^ 0x9e3779b9u;
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

static NetworkInterface_t interface;
static NetworkEndPoint_t endpoint;

int main(uint32_t magic, struct mbi *mbi)
{
	const char *line = (mbi->flags & 4) ? (const char *)(uintptr_t)mbi->cmdline : "";
	char cidr[32];
	uint8_t ip[4], mask[4], gw[4] = { 0 }, dns[4] = { 0 };
	int prefix;

	outb(0x21, 0xff);   /* mask the legacy PIC: the LAPIC drives the tick */
	outb(0xA1, 0xff);
	con_puts(magic == 0x2BADB002 ? "vxparts: FreeRTOS " tskKERNEL_VERSION_NUMBER " booting\n" : "vxparts: bad multiboot magic\n");
	con_puts("cmdline: ");
	con_puts(line);
	con_puts("\n");
	arg(line, "vx.node", node, sizeof(node));
	if (!arg(line, "vx.ip", cidr, sizeof(cidr)) || parse_cidr(cidr, ip, &prefix) != 0) {
		con_puts("vxparts: no usable vx.ip on the command line\n");
		for (;;) {
			__asm__ volatile("hlt");
		}
	}
	uint32_t m = prefix == 32 ? 0xffffffffu : ~(0xffffffffu >> prefix);

	for (int i = 0; i < 4; i++) {
		mask[i] = (uint8_t)(m >> (24 - 8 * i));
	}
	if (virtio_net_init() != 0) {
		con_puts("vxparts: no virtio-net device\n");
		for (;;) {
			__asm__ volatile("hlt");
		}
	}
	pxFillInterfaceDescriptor(0, &interface);
	FreeRTOS_FillEndPoint(&interface, &endpoint, ip, mask, gw, dns, virtio_net_mac());
	FreeRTOS_IPInit_Multi();
	vTaskStartScheduler();
	con_puts("scheduler returned\n");
	for (;;) {
	}
}
