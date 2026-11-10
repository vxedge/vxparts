#ifndef VIRTIO_NET_H
#define VIRTIO_NET_H
#include <stdint.h>
int virtio_net_probe(void);
int virtio_net_init(void);
const uint8_t *virtio_net_mac(void);
#endif
