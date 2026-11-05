/* A UDP reflector for vxedge's qemu-microvm backend.
 *
 * The zone-backend contract hands the guest its address on the kernel command line
 * (`vx.ip=<cidr>`), and QEMU passes that line to a Multiboot kernel after the kernel's own path.
 * The MAC is the one QEMU gave the NIC, read from the virtio device configuration, so vxedge's
 * per-node MAC reaches the wire. The payload echoes every datagram on :9800, as vxprobe does.
 */
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <zephyr/arch/x86/multiboot.h>
#include <zephyr/drivers/virtio.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/net/net_if.h>
#include <zephyr/net/socket.h>

LOG_MODULE_REGISTER(vxprobe, LOG_LEVEL_INF);

#define PORT 9800

static const char *cmdline(void)
{
	if (!(multiboot_info.flags & MULTIBOOT_INFO_FLAGS_CMDLINE)) {
		return "";
	}
	/* No MMU: the loader's copy of the line is addressable as it stands. */
	return (const char *)(uintptr_t)multiboot_info.cmdline;
}

/* The value of `key=` in the command line, copied into out. */
static bool arg(const char *line, const char *key, char *out, size_t len)
{
	size_t kl = strlen(key);

	for (const char *p = line; *p; p++) {
		if ((p == line || p[-1] == ' ') && strncmp(p, key, kl) == 0 && p[kl] == '=') {
			size_t n = strcspn(p + kl + 1, " ");

			if (n >= len) {
				return false;
			}
			memcpy(out, p + kl + 1, n);
			out[n] = '\0';
			return true;
		}
	}
	return false;
}

static int set_ip(struct net_if *iface, char *cidr)
{
	char *slash = strchr(cidr, '/');
	struct in_addr addr, mask;
	int prefix = 24;

	if (slash) {
		*slash = '\0';
		prefix = atoi(slash + 1);
	}
	if (prefix < 1 || prefix > 32 || net_addr_pton(AF_INET, cidr, &addr) < 0) {
		return -EINVAL;
	}
	mask.s_addr = htonl(0xffffffffU << (32 - prefix));
	if (!net_if_ipv4_addr_add(iface, &addr, NET_ADDR_MANUAL, 0)) {
		return -ENOMEM;
	}
	net_if_ipv4_set_netmask_by_addr(iface, &addr, &mask);
	return 0;
}

/* The MAC QEMU gave the NIC lives in the first six bytes of the virtio net configuration. */
static void use_device_mac(struct net_if *iface)
{
	const struct device *vdev = DEVICE_DT_GET(DT_NODELABEL(virtio_mmio0));
	const uint8_t *cfg = virtio_get_device_specific_config(vdev);

	if (cfg == NULL) {
		LOG_WRN("no device configuration, keeping the driver's MAC");
		return;
	}
	net_if_down(iface);
	net_if_set_link_addr(iface, (uint8_t *)cfg, 6, NET_LINK_ETHERNET);
	net_if_up(iface);
}

int main(void)
{
	const char *line = cmdline();
	char cidr[32], node[48] = "unknown";
	struct net_if *iface = net_if_get_default();

	LOG_INF("cmdline: %s", line);
	if (iface == NULL) {
		LOG_ERR("no network interface");
		return 1;
	}
	use_device_mac(iface);
	arg(line, "vx.node", node, sizeof(node));
	if (!arg(line, "vx.ip", cidr, sizeof(cidr)) || set_ip(iface, cidr) != 0) {
		LOG_ERR("no usable vx.ip on the command line");
		return 1;
	}
	LOG_INF("vxparts guest up: node=%s, starting reflector :%d", node, PORT);

	int sock = zsock_socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	struct sockaddr_in bind_addr = {
		.sin_family = AF_INET,
		.sin_port = htons(PORT),
	};

	if (sock < 0 || zsock_bind(sock, (struct sockaddr *)&bind_addr, sizeof(bind_addr)) < 0) {
		LOG_ERR("cannot bind :%d (%d)", PORT, errno);
		return 1;
	}
	for (;;) {
		static uint8_t buf[1500];
		struct sockaddr_in peer;
		socklen_t plen = sizeof(peer);
		ssize_t n = zsock_recvfrom(sock, buf, sizeof(buf), 0, (struct sockaddr *)&peer, &plen);

		if (n > 0) {
			(void)zsock_sendto(sock, buf, n, 0, (struct sockaddr *)&peer, plen);
		}
	}
}
