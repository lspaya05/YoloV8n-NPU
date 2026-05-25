// SPDX-License-Identifier: GPL-2.0
/*
 * EE470 INT8 NPU platform driver.
 *
 * Hardware contract:
 * - AXI-Lite CSR window is supplied by device tree resource 0.
 * - A single completion IRQ fires after the final DMA_STORE of a dispatch.
 * - Instructions are 128-bit words in a coherent instruction buffer.
 * - The sequencer fetches instructions from DDR by physical address.
 */

#include <linux/completion.h>
#include <linux/dma-mapping.h>
#include <linux/fs.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/overflow.h>
#include <linux/platform_device.h>
#include <linux/poll.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/wait.h>

#include "npu_uapi.h"

#define EE470_NPU_DRV_NAME "ee470-npu"

#define NPU_REG_VERSION		0x00
#define NPU_REG_CONTROL		0x04
#define NPU_REG_STATUS		0x08
#define NPU_REG_IRQ_ENABLE	0x0c
#define NPU_REG_IRQ_STATUS	0x10
#define NPU_REG_INSTR_BASE_LO	0x20
#define NPU_REG_INSTR_BASE_HI	0x24
#define NPU_REG_INSTR_COUNT	0x28
#define NPU_REG_BUF_BASE	0x40

#define NPU_CONTROL_START	BIT(0)
#define NPU_CONTROL_RESET	BIT(1)
#define NPU_STATUS_BUSY		BIT(0)
#define NPU_STATUS_DONE		BIT(1)
#define NPU_STATUS_ERROR	BIT(2)
#define NPU_IRQ_DONE		BIT(0)
#define NPU_IRQ_ERROR		BIT(1)

#define NPU_DEFAULT_TIMEOUT_MS 1000

struct npu_buffer {
	const char *name;
	size_t size;
	u32 flags;
	void *cpu;
	dma_addr_t dma;
};

struct npu_dev {
	struct device *dev;
	void __iomem *regs;
	int irq;
	struct miscdevice miscdev;
	struct completion done;
	wait_queue_head_t poll_wait;
	struct mutex lock;
	u32 last_status;
	struct npu_buffer bufs[EE470_NPU_NUM_BUFS];
};

static const struct npu_buffer npu_default_bufs[EE470_NPU_NUM_BUFS] = {
	[EE470_NPU_BUF_INSTR] = {
		.name = "instr",
		.size = 64 * 1024,
		.flags = EE470_NPU_BUF_F_TO_DEVICE,
	},
	[EE470_NPU_BUF_WEIGHTS] = {
		.name = "weights",
		.size = 4 * 1024 * 1024,
		.flags = EE470_NPU_BUF_F_TO_DEVICE,
	},
	[EE470_NPU_BUF_COEFF] = {
		.name = "coeff",
		.size = 64 * 1024,
		.flags = EE470_NPU_BUF_F_TO_DEVICE,
	},
	[EE470_NPU_BUF_INPUT] = {
		.name = "input",
		.size = 640 * 640 * 3,
		.flags = EE470_NPU_BUF_F_TO_DEVICE,
	},
	[EE470_NPU_BUF_ACTIVATION] = {
		.name = "activation",
		.size = 33 * 1024 * 1024,
		.flags = EE470_NPU_BUF_F_TO_DEVICE | EE470_NPU_BUF_F_FROM_DEVICE,
	},
	[EE470_NPU_BUF_SKIP] = {
		.name = "skip",
		.size = 1024 * 1024,
		.flags = EE470_NPU_BUF_F_TO_DEVICE | EE470_NPU_BUF_F_FROM_DEVICE,
	},
	[EE470_NPU_BUF_LUT] = {
		.name = "lut",
		.size = 64 * 1024,
		.flags = EE470_NPU_BUF_F_TO_DEVICE,
	},
	[EE470_NPU_BUF_OUTPUT] = {
		.name = "output",
		.size = 2 * 1024 * 1024,
		.flags = EE470_NPU_BUF_F_FROM_DEVICE,
	},
};

static struct npu_dev *file_to_npu(struct file *file)
{
	return container_of(file->private_data, struct npu_dev, miscdev);
}

static void npu_writel(struct npu_dev *npu, u32 val, u32 off)
{
	writel(val, npu->regs + off);
}

static u32 npu_readl(struct npu_dev *npu, u32 off)
{
	return readl(npu->regs + off);
}

static void npu_register_buffers(struct npu_dev *npu)
{
	unsigned int i;

	for (i = 0; i < EE470_NPU_NUM_BUFS; i++) {
		dma_addr_t addr = npu->bufs[i].dma;
		u32 off = NPU_REG_BUF_BASE + i * 8;

		npu_writel(npu, lower_32_bits(addr), off);
		npu_writel(npu, upper_32_bits(addr), off + 4);
	}
}

static int npu_validate_transfer(struct npu_dev *npu,
				 const struct ee470_npu_transfer *xfer)
{
	u64 end;

	if (xfer->buffer_id >= EE470_NPU_NUM_BUFS)
		return -EINVAL;
	if (check_add_overflow(xfer->offset, xfer->size, &end))
		return -EINVAL;
	if (end > npu->bufs[xfer->buffer_id].size)
		return -EINVAL;
	if (!xfer->user_ptr && xfer->size)
		return -EINVAL;

	return 0;
}

static int npu_copy_to_buffer(struct npu_dev *npu,
			      const struct ee470_npu_transfer *xfer)
{
	struct npu_buffer *buf = &npu->bufs[xfer->buffer_id];

	if (!(buf->flags & EE470_NPU_BUF_F_TO_DEVICE))
		return -EPERM;
	if (copy_from_user((u8 *)buf->cpu + xfer->offset,
			   u64_to_user_ptr(xfer->user_ptr), xfer->size))
		return -EFAULT;

	return 0;
}

static int npu_copy_from_buffer(struct npu_dev *npu,
				const struct ee470_npu_transfer *xfer)
{
	struct npu_buffer *buf = &npu->bufs[xfer->buffer_id];

	if (!(buf->flags & EE470_NPU_BUF_F_FROM_DEVICE))
		return -EPERM;
	if (copy_to_user(u64_to_user_ptr(xfer->user_ptr),
			 (u8 *)buf->cpu + xfer->offset, xfer->size))
		return -EFAULT;

	return 0;
}

static long npu_query_buffers(struct npu_dev *npu, unsigned long arg)
{
	struct ee470_npu_query_buffers query = {};
	unsigned int i;

	query.count = EE470_NPU_NUM_BUFS;
	for (i = 0; i < EE470_NPU_NUM_BUFS; i++) {
		query.desc[i].id = i;
		query.desc[i].flags = npu->bufs[i].flags;
		query.desc[i].size = npu->bufs[i].size;
		query.desc[i].dma_addr = npu->bufs[i].dma;
		query.desc[i].mmap_offset = i;
	}

	if (copy_to_user((void __user *)arg, &query, sizeof(query)))
		return -EFAULT;

	return 0;
}

static long npu_dispatch(struct npu_dev *npu, unsigned long arg)
{
	struct ee470_npu_dispatch dispatch;
	struct npu_buffer *instr = &npu->bufs[EE470_NPU_BUF_INSTR];
	size_t instr_bytes;
	unsigned long timeout;
	int ret = 0;

	if (copy_from_user(&dispatch, (void __user *)arg, sizeof(dispatch)))
		return -EFAULT;

	if (!dispatch.instr_count || dispatch.instr_count > EE470_NPU_MAX_INSTR)
		return -EINVAL;

	instr_bytes = dispatch.instr_count * EE470_NPU_INSTR_BYTES;
	if (instr_bytes > instr->size)
		return -EINVAL;

	mutex_lock(&npu->lock);

	if (npu_readl(npu, NPU_REG_STATUS) & NPU_STATUS_BUSY) {
		ret = -EBUSY;
		goto out_unlock;
	}

	if (copy_from_user(instr->cpu, u64_to_user_ptr(dispatch.instr_user_ptr),
			   instr_bytes)) {
		ret = -EFAULT;
		goto out_unlock;
	}

	reinit_completion(&npu->done);
	npu->last_status = 0;
	npu_register_buffers(npu);

	npu_writel(npu, NPU_IRQ_DONE | NPU_IRQ_ERROR, NPU_REG_IRQ_STATUS);
	npu_writel(npu, NPU_IRQ_DONE | NPU_IRQ_ERROR, NPU_REG_IRQ_ENABLE);
	npu_writel(npu, lower_32_bits(instr->dma), NPU_REG_INSTR_BASE_LO);
	npu_writel(npu, upper_32_bits(instr->dma), NPU_REG_INSTR_BASE_HI);
	npu_writel(npu, dispatch.instr_count, NPU_REG_INSTR_COUNT);
	npu_writel(npu, NPU_CONTROL_START, NPU_REG_CONTROL);

	if (!dispatch.timeout_ms)
		goto out_unlock;

	timeout = msecs_to_jiffies(dispatch.timeout_ms);
	if (!wait_for_completion_timeout(&npu->done, timeout)) {
		ret = -ETIMEDOUT;
		goto out_unlock;
	}

	if (npu->last_status & NPU_STATUS_ERROR)
		ret = -EIO;

out_unlock:
	mutex_unlock(&npu->lock);
	return ret;
}

static long npu_wait_done(struct npu_dev *npu, unsigned long arg)
{
	struct ee470_npu_wait wait;
	unsigned long timeout;
	int ret = 0;

	if (copy_from_user(&wait, (void __user *)arg, sizeof(wait)))
		return -EFAULT;

	timeout = msecs_to_jiffies(wait.timeout_ms ?: NPU_DEFAULT_TIMEOUT_MS);
	if (!wait_for_completion_timeout(&npu->done, timeout))
		return -ETIMEDOUT;

	wait.status = npu->last_status;
	if (copy_to_user((void __user *)arg, &wait, sizeof(wait)))
		return -EFAULT;

	if (wait.status & NPU_STATUS_ERROR)
		ret = -EIO;

	return ret;
}

static long npu_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct npu_dev *npu = file_to_npu(file);
	struct ee470_npu_transfer xfer;
	int ret;

	switch (cmd) {
	case EE470_NPU_IOC_QUERY_BUFFERS:
		return npu_query_buffers(npu, arg);
	case EE470_NPU_IOC_LOAD_WEIGHTS:
	case EE470_NPU_IOC_WRITE_BUFFER:
		if (copy_from_user(&xfer, (void __user *)arg, sizeof(xfer)))
			return -EFAULT;
		if (cmd == EE470_NPU_IOC_LOAD_WEIGHTS)
			xfer.buffer_id = EE470_NPU_BUF_WEIGHTS;
		ret = npu_validate_transfer(npu, &xfer);
		if (ret)
			return ret;
		return npu_copy_to_buffer(npu, &xfer);
	case EE470_NPU_IOC_READ_BUFFER:
		if (copy_from_user(&xfer, (void __user *)arg, sizeof(xfer)))
			return -EFAULT;
		ret = npu_validate_transfer(npu, &xfer);
		if (ret)
			return ret;
		return npu_copy_from_buffer(npu, &xfer);
	case EE470_NPU_IOC_DISPATCH:
		return npu_dispatch(npu, arg);
	case EE470_NPU_IOC_WAIT_DONE:
		return npu_wait_done(npu, arg);
	case EE470_NPU_IOC_RESET:
		npu_writel(npu, NPU_CONTROL_RESET, NPU_REG_CONTROL);
		reinit_completion(&npu->done);
		npu->last_status = 0;
		return 0;
	default:
		return -ENOIOCTLCMD;
	}
}

static int npu_mmap(struct file *file, struct vm_area_struct *vma)
{
	struct npu_dev *npu = file_to_npu(file);
	unsigned long id = vma->vm_pgoff;
	struct npu_buffer *buf;
	size_t size = vma->vm_end - vma->vm_start;

	if (id >= EE470_NPU_NUM_BUFS)
		return -EINVAL;

	buf = &npu->bufs[id];
	if (size > buf->size)
		return -EINVAL;

	vma->vm_pgoff = 0;
	return dma_mmap_coherent(npu->dev, vma, buf->cpu, buf->dma, buf->size);
}

static __poll_t npu_poll(struct file *file, poll_table *wait)
{
	struct npu_dev *npu = file_to_npu(file);

	poll_wait(file, &npu->poll_wait, wait);
	if (completion_done(&npu->done))
		return EPOLLIN | EPOLLRDNORM;

	return 0;
}

static const struct file_operations npu_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = npu_ioctl,
	.compat_ioctl = npu_ioctl,
	.mmap = npu_mmap,
	.poll = npu_poll,
};

static irqreturn_t npu_irq(int irq, void *data)
{
	struct npu_dev *npu = data;
	u32 irq_status = npu_readl(npu, NPU_REG_IRQ_STATUS);

	if (!(irq_status & (NPU_IRQ_DONE | NPU_IRQ_ERROR)))
		return IRQ_NONE;

	npu_writel(npu, irq_status, NPU_REG_IRQ_STATUS);
	npu->last_status = npu_readl(npu, NPU_REG_STATUS);
	complete_all(&npu->done);
	wake_up_interruptible(&npu->poll_wait);

	return IRQ_HANDLED;
}

static int npu_alloc_buffers(struct npu_dev *npu)
{
	unsigned int i;

	memcpy(npu->bufs, npu_default_bufs, sizeof(npu_default_bufs));

	for (i = 0; i < EE470_NPU_NUM_BUFS; i++) {
		struct npu_buffer *buf = &npu->bufs[i];

		buf->cpu = dmam_alloc_coherent(npu->dev, buf->size, &buf->dma,
					       GFP_KERNEL);
		if (!buf->cpu)
			return -ENOMEM;

		dev_info(npu->dev, "%s buffer: cpu=%p dma=%pad size=%zu\n",
			 buf->name, buf->cpu, &buf->dma, buf->size);
	}

	return 0;
}

static int npu_probe(struct platform_device *pdev)
{
	struct npu_dev *npu;
	int ret;

	npu = devm_kzalloc(&pdev->dev, sizeof(*npu), GFP_KERNEL);
	if (!npu)
		return -ENOMEM;

	npu->dev = &pdev->dev;
	mutex_init(&npu->lock);
	init_completion(&npu->done);
	init_waitqueue_head(&npu->poll_wait);
	platform_set_drvdata(pdev, npu);

	npu->regs = devm_platform_ioremap_resource(pdev, 0);
	if (IS_ERR(npu->regs))
		return PTR_ERR(npu->regs);

	npu->irq = platform_get_irq(pdev, 0);
	if (npu->irq < 0)
		return npu->irq;

	ret = dma_set_mask_and_coherent(npu->dev, DMA_BIT_MASK(32));
	if (ret)
		return ret;

	ret = npu_alloc_buffers(npu);
	if (ret)
		return ret;

	ret = devm_request_irq(npu->dev, npu->irq, npu_irq, 0,
			       dev_name(npu->dev), npu);
	if (ret)
		return ret;

	npu->miscdev.minor = MISC_DYNAMIC_MINOR;
	npu->miscdev.name = EE470_NPU_DEVICE_NAME;
	npu->miscdev.fops = &npu_fops;
	npu->miscdev.parent = npu->dev;

	ret = misc_register(&npu->miscdev);
	if (ret)
		return ret;

	npu_writel(npu, NPU_CONTROL_RESET, NPU_REG_CONTROL);
	npu_register_buffers(npu);

	dev_info(npu->dev, "registered /dev/%s version=0x%08x\n",
		 EE470_NPU_DEVICE_NAME, npu_readl(npu, NPU_REG_VERSION));

	return 0;
}

static int npu_remove(struct platform_device *pdev)
{
	struct npu_dev *npu = platform_get_drvdata(pdev);

	misc_deregister(&npu->miscdev);
	return 0;
}

static const struct of_device_id npu_of_match[] = {
	{ .compatible = "ee470,npu-v2" },
	{ .compatible = "mynpu,v2" },
	{ }
};
MODULE_DEVICE_TABLE(of, npu_of_match);

static struct platform_driver npu_platform_driver = {
	.probe = npu_probe,
	.remove = npu_remove,
	.driver = {
		.name = EE470_NPU_DRV_NAME,
		.of_match_table = npu_of_match,
	},
};
module_platform_driver(npu_platform_driver);

MODULE_AUTHOR("EE470 Final Project");
MODULE_DESCRIPTION("EE470 KR260 INT8 NPU platform character driver");
MODULE_LICENSE("GPL");
