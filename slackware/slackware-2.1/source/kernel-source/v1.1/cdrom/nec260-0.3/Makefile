KERNELSRC = /usr/src/linux
CFLAGS = -O2 -Wall -D__KERNEL__ -I$(KERNELSRC)/drivers/block

nec260.o : nec260.c version.h

VERS = $(KERNELSRC)/tools/version.h

version.h : $(VERS)
	@echo char kernel_version[] = \"`getrel $(VERS)`\"\; > version.h
	@echo '#define KERNEL_MAJOR' \
          `getrel $(VERS) | sed 's/\..*//'` >>version.h
	@echo '#define KERNEL_MINOR' \
          `getrel $(VERS) | sed 's/[^.]*\.//;s/\..*//'` >>version.h
	@echo '#define KERNEL_PATCH' \
          `getrel $(VERS) | sed 's/.*\.//'` >>version.h
