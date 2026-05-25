/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _UAPI_EE470_NPU_H
#define _UAPI_EE470_NPU_H

#include <linux/ioctl.h>
#include <linux/types.h>

#define EE470_NPU_DEVICE_NAME "npu0"
#define EE470_NPU_IOCTL_MAGIC 'N'
#define EE470_NPU_INSTR_BYTES 16
#define EE470_NPU_MAX_INSTR 4096

enum ee470_npu_buffer_id {
	EE470_NPU_BUF_INSTR = 0,
	EE470_NPU_BUF_WEIGHTS,
	EE470_NPU_BUF_COEFF,
	EE470_NPU_BUF_INPUT,
	EE470_NPU_BUF_ACTIVATION,
	EE470_NPU_BUF_SKIP,
	EE470_NPU_BUF_LUT,
	EE470_NPU_BUF_OUTPUT,
	EE470_NPU_NUM_BUFS
};

enum ee470_npu_buffer_flags {
	EE470_NPU_BUF_F_TO_DEVICE = 1u << 0,
	EE470_NPU_BUF_F_FROM_DEVICE = 1u << 1,
};

struct ee470_npu_buffer_desc {
	__u32 id;
	__u32 flags;
	__u64 size;
	__u64 dma_addr;
	__u64 mmap_offset;
};

struct ee470_npu_query_buffers {
	__u32 count;
	__u32 reserved;
	struct ee470_npu_buffer_desc desc[EE470_NPU_NUM_BUFS];
};

struct ee470_npu_transfer {
	__u32 buffer_id;
	__u32 reserved;
	__u64 offset;
	__u64 size;
	__u64 user_ptr;
};

struct ee470_npu_dispatch {
	__u64 instr_user_ptr;
	__u32 instr_count;
	__u32 flags;
	__u32 timeout_ms;
	__u32 reserved;
};

struct ee470_npu_wait {
	__u32 timeout_ms;
	__u32 status;
};

#define EE470_NPU_IOC_QUERY_BUFFERS \
	_IOR(EE470_NPU_IOCTL_MAGIC, 0x00, struct ee470_npu_query_buffers)
#define EE470_NPU_IOC_LOAD_WEIGHTS \
	_IOW(EE470_NPU_IOCTL_MAGIC, 0x01, struct ee470_npu_transfer)
#define EE470_NPU_IOC_WRITE_BUFFER \
	_IOW(EE470_NPU_IOCTL_MAGIC, 0x02, struct ee470_npu_transfer)
#define EE470_NPU_IOC_READ_BUFFER \
	_IOWR(EE470_NPU_IOCTL_MAGIC, 0x03, struct ee470_npu_transfer)
#define EE470_NPU_IOC_DISPATCH \
	_IOW(EE470_NPU_IOCTL_MAGIC, 0x04, struct ee470_npu_dispatch)
#define EE470_NPU_IOC_WAIT_DONE \
	_IOWR(EE470_NPU_IOCTL_MAGIC, 0x05, struct ee470_npu_wait)
#define EE470_NPU_IOC_RESET \
	_IO(EE470_NPU_IOCTL_MAGIC, 0x06)

#endif /* _UAPI_EE470_NPU_H */
