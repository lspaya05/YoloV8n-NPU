// SPDX-License-Identifier: GPL-2.0
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "npu_uapi.h"

int main(void)
{
	struct ee470_npu_query_buffers query;
	int fd;

	fd = open("/dev/" EE470_NPU_DEVICE_NAME, O_RDWR);
	if (fd < 0) {
		perror("open");
		return 1;
	}

	memset(&query, 0, sizeof(query));
	if (ioctl(fd, EE470_NPU_IOC_QUERY_BUFFERS, &query) < 0) {
		perror("QUERY_BUFFERS");
		close(fd);
		return 1;
	}

	printf("NPU buffers: %u\n", query.count);
	for (uint32_t i = 0; i < query.count; i++) {
		printf("  id=%u size=%llu dma=0x%llx flags=0x%x mmap_offset=%llu\n",
		       query.desc[i].id,
		       (unsigned long long)query.desc[i].size,
		       (unsigned long long)query.desc[i].dma_addr,
		       query.desc[i].flags,
		       (unsigned long long)query.desc[i].mmap_offset);
	}

	close(fd);
	return 0;
}
