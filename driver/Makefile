obj-m += ee470_npu.o
ee470_npu-y := npu_driver.o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

smoke:
	$(CC) -Wall -Wextra -O2 -o npu_smoke npu_smoke.c

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	$(RM) npu_smoke
