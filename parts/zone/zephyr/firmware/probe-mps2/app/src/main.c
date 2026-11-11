/* A UDP reflector for vxedge's qemu-mcu backend: Zephyr on QEMU's mps2-an385 (Cortex-M3)
 * with its LAN9118 NIC (Zephyr's smsc911x driver, which takes the MAC QEMU gave the NIC).
 *
 * The backend passes `vx.ip=<cidr> vx.node=<id>` as the semihosting command line, read here
 * with SYS_GET_CMDLINE. Every datagram on :9800 is echoed back.
 */
#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/version.h>
#include <zephyr/sys/printk.h>
#include <zephyr/arch/common/semihost.h>
#include <zephyr/net/net_if.h>
#include <zephyr/net/socket.h>

#define PORT 9800

static int get_cmdline(char *buf, size_t len)
{
	struct { char *buf; long len; } blk = { buf, (long)len };

	if (semihost_exec(SEMIHOST_GET_CMDLINE, &blk) != 0) {
		buf[0] = 0;
		return -1;
	}
	buf[(size_t)blk.len < len ? (size_t)blk.len : len - 1] = 0;
	return 0;
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

int main(void)
{
	static char line[256];
	static uint8_t buf[1500];
	char cidr[32], node[48] = "unknown";
	struct net_in_addr addr, mask;
	int prefix;

	printk("vxparts: Zephyr %s on mps2-an385 booting\n", KERNEL_VERSION_STRING);
	get_cmdline(line, sizeof(line));
	printk("cmdline: %s\n", line);
	arg(line, "vx.node", node, sizeof(node));
	if (!arg(line, "vx.ip", cidr, sizeof(cidr)) || parse_cidr(cidr, (uint8_t *)&addr, &prefix) != 0) {
		printk("vxparts: no usable vx.ip on the command line\n");
		return 0;
	}
	uint32_t m = prefix == 32 ? 0xffffffffu : ~(0xffffffffu >> prefix);

	mask.s_addr = net_htonl(m);

	struct net_if *iface = net_if_get_default();
	struct net_linkaddr *ll = net_if_get_link_addr(iface);

	printk("mac: %02x:%02x:%02x:%02x:%02x:%02x\n", ll->addr[0], ll->addr[1], ll->addr[2],
	       ll->addr[3], ll->addr[4], ll->addr[5]);
	if (!net_if_ipv4_addr_add(iface, &addr, NET_ADDR_MANUAL, 0) ||
	    !net_if_ipv4_set_netmask_by_addr(iface, &addr, &mask)) {
		printk("vxparts: cannot set the address\n");
		return 0;
	}

	int s = zsock_socket(NET_AF_INET, NET_SOCK_DGRAM, NET_IPPROTO_UDP);
	struct net_sockaddr_in me = { .sin_family = NET_AF_INET, .sin_port = net_htons(PORT) };

	if (s < 0 || zsock_bind(s, (struct net_sockaddr *)&me, sizeof(me)) < 0) {
		printk("vxparts: cannot bind :9800\n");
		return 0;
	}
	printk("vxparts guest up: node=%s, starting reflector :9800\n", node);
	for (;;) {
		struct net_sockaddr_in peer;
		net_socklen_t plen = sizeof(peer);
		ssize_t n = zsock_recvfrom(s, buf, sizeof(buf), 0, (struct net_sockaddr *)&peer, &plen);

		if (n > 0) {
			(void)zsock_sendto(s, buf, (size_t)n, 0, (struct net_sockaddr *)&peer, plen);
		}
	}
}
